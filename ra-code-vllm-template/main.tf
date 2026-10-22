terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "coder" {
}

provider "kubernetes" {
  # Authenticate via ~/.kube/config or a Coder-specific ServiceAccount, depending on admin preferences
  config_path = false == true ? "~/.kube/config" : null
}

# ---------------------------------------------------------------------------
# GPU types. To support a new node type, add one entry here and one option
# to the gpu_type parameter below.
# ---------------------------------------------------------------------------
locals {
  gpu_types = {
    "none"     = { product = null, arch = "amd64" }
    "a5000"    = { product = "NVIDIA-RTX-A5000", arch = "amd64" }
    "6000-ada" = { product = "NVIDIA-RTX-6000-Ada", arch = "amd64" }
    "6000-bw"  = { product = "NVIDIA-RTX-6000-Blackwell", arch = "amd64" }
    "gb10"     = { product = "NVIDIA-Grace-Blackwell-GB10", arch = "arm64" }
  }
  gpu     = local.gpu_types[data.coder_parameter.gpu_type.value]
  has_gpu = local.gpu.product != null

  node_selector = merge(
    { "kubernetes.io/arch" = local.gpu.arch },
    local.has_gpu ? { "nvidia.com/gpu.product" = local.gpu.product } : {}
  )

  limits = merge(
    {
      "cpu"    = data.coder_parameter.cpu.value
      "memory" = "${data.coder_parameter.memory.value}Gi"
    },
    local.has_gpu ? { "nvidia.com/gpu" = "1" } : {}
  )

  # vLLM runs as a sidecar from the official multi-arch image (via the
  # Harbor Docker Hub proxy, as the registry policy requires). v0.32.0 is
  # the version NVIDIA's Nemotron 3.5 Super VL card specifies.
  vllm_image       = "harbor.ra.se/cache-dockerhub/vllm/vllm-openai:v0.32.0"
  opencode_version = "1.19.0"

  # Model catalog (HuggingFace repos, served by vLLM). Rules (see README):
  #   1. tool calling verified end-to-end through the vLLM OpenAI API
  #   2. weights (+KV) fit a workspace GPU tier, quantized variants allowed
  #   3. newest generation of each family
  #   4. vision and coding options where the tier allows
  # Sizes are safetensors sums from the HF API; the GPU needs that plus KV.
  # VRAM: A5000 24 GB, 6000 Ada 48 GB, 6000 Blackwell 96 GB, GB10 128 GB shared.
  # gated=true models need a HF token with the license accepted (hf_token param).
  vllm_models = [
    # Every GPU (A5000 and up)
    { value = "openai/gpt-oss-20b", name = "gpt-oss 20B", description = "13.8 GB MXFP4 - OpenAI open weights, reasoning; every GPU", vision = false, gated = false, tool_parser = "openai", reasoning_parser = "openai_gptoss", extra_args = "" },
    { value = "google/gemma-4-E2B-it", name = "Gemma 4 E2B", description = "10.2 GB - Google, vision; smallest; every GPU", vision = true, gated = false, tool_parser = "gemma4", reasoning_parser = "gemma4", extra_args = "" },
    { value = "google/gemma-4-E4B-it", name = "Gemma 4 E4B", description = "16.0 GB - Google, vision, fast; every GPU (default)", vision = true, gated = false, tool_parser = "gemma4", reasoning_parser = "gemma4", extra_args = "" },
    # 6000 Ada and up
    { value = "Qwen/Qwen3.5-9B", name = "Qwen 3.5 9B", description = "19.3 GB - Alibaba, thinking; 6000 Ada or larger", vision = false, gated = false, tool_parser = "qwen3_coder", reasoning_parser = "qwen3", extra_args = "" },
    { value = "google/gemma-4-12B-it", name = "Gemma 4 12B", description = "23.9 GB - Google, vision, 256K context; 6000 Ada or larger", vision = true, gated = false, tool_parser = "gemma4", reasoning_parser = "gemma4", extra_args = "" },
    { value = "mistralai/Ministral-3-14B-Instruct", name = "Ministral 3 14B [gated]", description = "~28 GB - Mistral, vision; needs HF token; 6000 Ada or larger", vision = true, gated = true, tool_parser = "mistral", reasoning_parser = "", extra_args = "" },
    { value = "Qwen/Qwen3.8-27B-FP8", name = "Qwen 3.8 27B (FP8)", description = "30.9 GB - Alibaba, coding + agents; 6000 Ada or larger", vision = false, gated = false, tool_parser = "qwen3_coder", reasoning_parser = "qwen3", extra_args = "--max-num-seqs 128" },
    # 6000 Blackwell and GB10
    { value = "mistralai/Devstral-Small-2-24B-Instruct", name = "Devstral Small 2 24B [gated]", description = "~48 GB - Mistral, built for coding agents; needs HF token; 6000 Blackwell or GB10", vision = true, gated = true, tool_parser = "mistral", reasoning_parser = "", extra_args = "" },
    { value = "google/gemma-4-26B-A4B-it", name = "Gemma 4 26B (MoE)", description = "51.6 GB - Google, vision, fast (4B active); 6000 Blackwell or GB10", vision = true, gated = false, tool_parser = "gemma4", reasoning_parser = "gemma4", extra_args = "" },
    { value = "openai/gpt-oss-120b", name = "gpt-oss 120B", description = "65.2 GB MXFP4 - OpenAI open weights, reasoning; 6000 Blackwell or GB10", vision = false, gated = false, tool_parser = "openai", reasoning_parser = "openai_gptoss", extra_args = "" },
    { value = "zai-org/GLM-4.7-Flash", name = "GLM 4.7 Flash (MoE)", description = "62.4 GB - Zhipu, thinking; 6000 Blackwell or GB10", vision = false, gated = false, tool_parser = "glm47", reasoning_parser = "glm47", extra_args = "" },
    { value = "google/gemma-4-31B-it", name = "Gemma 4 31B", description = "62.5 GB - Google, strongest Gemma 4, vision; 6000 Blackwell or GB10", vision = true, gated = false, tool_parser = "gemma4", reasoning_parser = "gemma4", extra_args = "" },
    { value = "Qwen/Qwen3.6-35B-A3B", name = "Qwen 3.6 35B (MoE)", description = "71.9 GB - Alibaba, agentic coding; 6000 Blackwell (tight) or GB10", vision = false, gated = false, tool_parser = "qwen3_coder", reasoning_parser = "qwen3", extra_args = "--max-num-seqs 128" },
    { value = "Qwen/Qwen3-Coder-Next-FP8", name = "Qwen 3 Coder Next 80B (FP8)", description = "80.4 GB - Alibaba, coding agent; GB10 (very tight on 6000 Blackwell)", vision = false, gated = false, tool_parser = "qwen3_coder", reasoning_parser = "", extra_args = "" },
    # GB10 only
    # Serve flags from NVIDIA's DGX Spark recipe on the model card (the
    # LiLiCorr speculative drafter is optional and left out). Requires
    # --trust-remote-code: the built-in config class expects vit_hidden_size
    # while the model's own code uses vision_hidden_size.
    { value = "nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4", name = "Nemotron 3.5 Super VL 120B (NVFP4)", description = "75.0 GB - NVIDIA, vision + agentic coding, 12B active; GB10 only", vision = true, gated = false, tool_parser = "qwen3_coder", reasoning_parser = "nemotron_v3", extra_args = "--trust-remote-code --mamba-backend flashinfer --mamba-ssm-cache-dtype float16 --enable-mamba-cache-stochastic-rounding --mamba-cache-philox-rounds 5 --enable-mamba-shared-prefix-checkpoint --block-size 64 --prefix-match-unit 64 --max-num-batched-tokens 8192 --max-num-seqs 1 --gpu-memory-utilization 0.85", image = "harbor.ra.se/cache-dockerhub/vllm/vllm-openai:nightly-3f1bcfd82bb2e93fcd364fc7a5491718453a77e2" },
  ]

  catalog_entry = (
    data.coder_parameter.vllm_model.value == "none" || data.coder_parameter.vllm_model.value == "custom"
    ? null
    : [for m in local.vllm_models : m if m.value == data.coder_parameter.vllm_model.value][0]
  )

  # "" = no model; "custom" = the free-text model parameter.
  model = (
    data.coder_parameter.vllm_model.value == "none" ? "" :
    data.coder_parameter.vllm_model.value == "custom" ? trimspace(data.coder_parameter.custom_model[0].value) :
    data.coder_parameter.vllm_model.value
  )
}

data "coder_parameter" "vllm_model" {
  name         = "vllm_model"
  display_name = "Local model (vLLM)"
  description  = "Downloaded from HuggingFace at workspace start onto the node's local disk (never NFS) and served by vLLM as OpenCode's default. Change it and restart to switch. First start of a big model can take 30+ minutes."
  default      = "google/gemma-4-E4B-it"
  icon         = "/emojis/1f999.png"
  mutable      = true
  form_type    = "dropdown"
  order        = 10

  dynamic "option" {
    for_each = local.vllm_models
    content {
      name        = option.value.name
      value       = option.value.value
      description = option.value.description
    }
  }
  option {
    name        = "Other (enter a name)"
    value       = "custom"
    description = "Any HuggingFace repo vLLM can serve, e.g. Qwen/Qwen3-32B"
  }
  option {
    name        = "None"
    value       = "none"
    description = "Start vLLM and OpenCode without a model (serve one yourself)"
  }
}

data "coder_parameter" "custom_model" {
  count        = data.coder_parameter.vllm_model.value == "custom" ? 1 : 0
  name         = "custom_model"
  display_name = "Model name"
  description  = "HuggingFace repo id, e.g. Qwen/Qwen3-32B"
  type         = "string"
  default      = ""
  mutable      = true
  order        = 11
  validation {
    regex = "^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$"
    error = "Use a HuggingFace repo id such as Qwen/Qwen3-32B"
  }
}

data "coder_parameter" "hf_token" {
  name         = "hf_token"
  display_name = "HuggingFace token (optional)"
  description  = "Needed only for gated models (marked [gated]): a HF access token with the model's license accepted. Leave empty for open models. Note: parameter values are visible to template admins."
  type         = "string"
  default      = ""
  mutable      = true
  order        = 12
}

data "coder_parameter" "context_length" {
  name         = "context_length"
  display_name = "Context length"
  description  = "vLLM max model context (--max-model-len). OpenCode needs at least 64K; larger windows use more GPU memory (KV cache)."
  default      = "65536"
  icon         = "/emojis/1f4cf.png"
  mutable      = true
  order        = 13
  option {
    name  = "32K"
    value = "32768"
  }
  option {
    name  = "64K"
    value = "65536"
  }
  option {
    name  = "128K"
    value = "131072"
  }
}

data "coder_parameter" "gpu_type" {
  name         = "gpu_type"
  display_name = "GPU"
  description  = "GPU attached to the workspace. Cannot be changed later; create a new workspace to switch."
  default      = "none"
  icon         = "/icon/memory.svg"
  mutable      = false
  option {
    name  = "None (CPU only)"
    value = "none"
  }
  option {
    name  = "NVIDIA RTX A5000 (x86)"
    value = "a5000"
  }
  option {
    name  = "NVIDIA RTX 6000 Ada (x86)"
    value = "6000-ada"
  }
  option {
    name  = "NVIDIA RTX 6000 Blackwell (x86)"
    value = "6000-bw"
  }
  option {
    name  = "NVIDIA GB10 Grace Blackwell (ARM)"
    value = "gb10"
  }
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU"
  description  = "CPU cores for the vLLM server (the dev container gets 2 more)"
  default      = "8"
  icon         = "/icon/memory.svg"
  mutable      = true
  option {
    name  = "2 Cores"
    value = "2"
  }
  option {
    name  = "4 Cores"
    value = "4"
  }
  option {
    name  = "8 Cores"
    value = "8"
  }
  option {
    name  = "16 Cores"
    value = "16"
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory"
  description  = "RAM for the vLLM server in GB (the dev container gets 8 GB more). On the GB10 the model itself lives in this unified memory: pick 96 GB for 120B-class models."
  default      = "32"
  icon         = "/icon/memory.svg"
  mutable      = true
  option {
    name  = "8 GB"
    value = "8"
  }
  option {
    name  = "16 GB"
    value = "16"
  }
  option {
    name  = "32 GB"
    value = "32"
  }
  option {
    name  = "64 GB"
    value = "64"
  }
  option {
    name  = "96 GB"
    value = "96"
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "The size of the home disk in GB"
  default      = "20"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false
  validation {
    min = 1
    max = 500
  }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = local.gpu.arch
  startup_script = <<-EOT
    set -e

    # Add any commands that should be executed at workspace startup (e.g install requirements, start a program, etc) here
  EOT

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "GPU Usage"
    key          = "2_gpu_usage"
    script       = "command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{ printf \"%s%%\", $1 }' || echo 'No GPU'"
    interval     = 10
    timeout      = 2
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  metadata {
    display_name = "Local Model"
    key          = "7_local_model"
    script       = <<-EOT
      curl -sf http://127.0.0.1:8000/v1/models | jq -r '.data[0].id // empty' | grep . || echo "not loaded"
    EOT
    interval     = 15
    timeout      = 3
  }
}

resource "coder_script" "vllm_setup" {
  agent_id           = coder_agent.main.id
  display_name       = "RA-CODE (vLLM + OpenCode)"
  icon               = "/emojis/1f999.png"
  log_path           = "vllm_setup.log"
  run_on_start       = true
  start_blocks_login = false
  script = templatefile("${path.module}/scripts/vllm_setup.sh", {
    model            = local.model
    model_vision     = local.catalog_entry != null && local.catalog_entry.vision ? "true" : "false"
    context_length   = data.coder_parameter.context_length.value
    opencode_version = local.opencode_version
    branding_b64     = base64encode(file("${path.module}/scripts/ra-code-branding.tsx"))
  })
}

resource "coder_app" "ra_code" {
  agent_id     = coder_agent.main.id
  slug         = "ra-code"
  display_name = "RA-CODE"
  icon         = "/icon/opencode.svg"
  command      = "ra-code"
  order        = 1
}

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = "coder"
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      //Coder-specific labels.
      "com.coder.resource"       = "true"
      "com.coder.workspace.id"   = data.coder_workspace.me.id
      "com.coder.workspace.name" = data.coder_workspace.me.name
      "com.coder.user.id"        = data.coder_workspace_owner.me.id
      "com.coder.user.username"  = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }
  wait_until_bound = false
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "nfs-client"
    resources {
      requests = {
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim_v1.home
  ]
  wait_for_rollout = false
  metadata {
    name      = "coder-${data.coder_workspace.me.id}"
    namespace = "coder"
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
        "app.kubernetes.io/part-of"  = "coder"
        "com.coder.resource"         = "true"
        "com.coder.workspace.id"     = data.coder_workspace.me.id
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "coder-workspace"
          "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
          "app.kubernetes.io/part-of"  = "coder"
          "com.coder.resource"         = "true"
          "com.coder.workspace.id"     = data.coder_workspace.me.id
          "com.coder.workspace.name"   = data.coder_workspace.me.name
          "com.coder.user.id"          = data.coder_workspace_owner.me.id
          "com.coder.user.username"    = data.coder_workspace_owner.me.name
        }
      }
      spec {
        node_selector      = local.node_selector
        runtime_class_name = local.has_gpu ? "nvidia" : null

        security_context {
          run_as_user     = 1000
          fs_group        = 1000
          run_as_non_root = true
        }

        # vLLM sidecar: serves the selected model on 127.0.0.1:8000 (pod
        # network namespace, so the dev container reaches it on localhost).
        # Downloads weights into the node-local emptyDir on every start -
        # never onto the NFS home volume - and takes minutes to become
        # ready, hence the generous startup probe.
        dynamic "container" {
          for_each = local.model != "" ? [1] : []
          content {
            name              = "vllm"
            image             = local.catalog_entry != null && lookup(local.catalog_entry, "image", "") != "" ? local.catalog_entry.image : local.vllm_image
            image_pull_policy = "IfNotPresent"
            # Log to the shared emptyDir so crashes can be read from the dev
            # container (coder ssh) - the agent cannot see sibling container logs.
            command = ["sh", "-c"]
            args = [join(" ", concat(
              ["exec vllm serve"],
              [
                "--model", local.model,
                "--served-model-name", local.model,
                "--host", "127.0.0.1",
                "--port", "8000",
                "--max-model-len", data.coder_parameter.context_length.value,
                "--gpu-memory-utilization", "0.90",
              ],
              # vLLM errors if --enable-auto-tool-choice has no parser;
              # gpt-oss (harmony) needs neither and keeps both empty.
              local.catalog_entry != null && local.catalog_entry.tool_parser != "" ? ["--enable-auto-tool-choice", "--tool-call-parser", local.catalog_entry.tool_parser] : [],
              local.catalog_entry != null && local.catalog_entry.reasoning_parser != "" ? ["--reasoning-parser", local.catalog_entry.reasoning_parser] : [],
              local.catalog_entry != null && local.catalog_entry.extra_args != "" ? split(" ", local.catalog_entry.extra_args) : [],
              [">> /opt/llm/vllm.log 2>&1"],
            ))]
            # uid 1000 has no writable home in the image; give it one.
            env {
              name  = "HOME"
              value = "/opt/llm/home"
            }
            env {
              name  = "HF_HOME"
              value = "/opt/llm/hf"
            }
            env {
              name  = "VLLM_CACHE_ROOT"
              value = "/opt/llm/vcache"
            }
            env {
              name  = "TRITON_CACHE_DIR"
              value = "/opt/llm/triton"
            }
            dynamic "env" {
              for_each = trimspace(data.coder_parameter.hf_token.value) != "" ? [1] : []
              content {
                name  = "HF_TOKEN"
                value = trimspace(data.coder_parameter.hf_token.value)
              }
            }
            resources {
              requests = {
                "cpu"    = "1"
                "memory" = "4Gi"
              }
              limits = local.limits
            }
            startup_probe {
              http_get {
                path = "/health"
                port = 8000
              }
              period_seconds    = 15
              failure_threshold = 160 # 40 min: first start downloads the weights
            }
            volume_mount {
              mount_path = "/opt/llm"
              name       = "llm"
            }
            volume_mount {
              mount_path = "/dev/shm"
              name       = "dshm"
            }
          }
        }

        container {
          name              = "dev"
          image             = "harbor.ra.se/cache-dockerhub/codercom/example-base:ubuntu"
          image_pull_policy = "Always"
          command           = ["sh", "-c", coder_agent.main.init_script]
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }
          env {
            name  = "NVIDIA_DRIVER_CAPABILITIES"
            value = "compute,utility"
          }
          env {
            name  = "PATH"
            value = "/home/coder/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          }
          # The GPU is allocated to the vllm sidecar only. The dev container
          # deliberately gets no NVIDIA_VISIBLE_DEVICES: env-based injection
          # conflicts with CDI-mode device plugin nodes and the container
          # then fails to start. GPU metadata shows "No GPU"; see the vllm
          # container for real GPU metrics.
          # OpenCode has no usage telemetry (OTLP export only runs when an
          # endpoint is configured). These stop its remaining calls home:
          # the hourly models.opencode.ai catalog fetch (unneeded, the
          # ollama provider is fully configured) and the update check.
          env {
            name  = "OPENCODE_DISABLE_MODELS_FETCH"
            value = "1"
          }
          env {
            name  = "OPENCODE_DISABLE_AUTOUPDATE"
            value = "1"
          }
          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
            # The bulk of cpu/memory goes to the vllm sidecar.
            limits = {
              "cpu"    = "2"
              "memory" = "8Gi"
            }
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }
          volume_mount {
            mount_path = "/opt/llm"
            name       = "llm"
          }
        }

        # HuggingFace cache on the node's local disk, not NFS. Wiped when
        # the pod goes away, so weights are downloaded again on start.
        volume {
          name = "llm"
          empty_dir {
            size_limit = "200Gi"
          }
        }

        # vLLM needs a real /dev/shm for its worker processes.
        volume {
          name = "dshm"
          empty_dir {
            medium     = "Memory"
            size_limit = "8Gi"
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.home.metadata.0.name
            read_only  = false
          }
        }

        affinity {
          # CPU-only workspaces prefer nodes without GPUs, keeping GPU nodes
          # free for GPU workspaces. They still fall back to a GPU node if
          # the CPU-only nodes are full.
          dynamic "node_affinity" {
            for_each = local.has_gpu ? [] : [1]
            content {
              preferred_during_scheduling_ignored_during_execution {
                weight = 100
                preference {
                  match_expressions {
                    key      = "nvidia.com/gpu.count"
                    operator = "DoesNotExist"
                  }
                }
              }
            }
          }

          # Spread workspaces across nodes.
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["coder-workspace"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}