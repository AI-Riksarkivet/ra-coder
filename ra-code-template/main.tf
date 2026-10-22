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

  # Ollama is copied out of the official multi-arch image (via the Harbor
  # Docker Hub proxy, as the registry policy requires) by an init
  # container; bump together with opencode when upgrading.
  ollama_image     = "harbor.ra.se/cache-dockerhub/ollama/ollama:0.40.5"
  opencode_version = "1.19.0"

  # Model catalog for the model parameter. Selection rules (see README):
  #   1. tool calling verified from the registry (template or built-in renderer)
  #   2. local weights that fit a workspace GPU
  #   3. updated within 12 months, newest generation of each family
  #   4. at least 1M pulls on ollama.com
  #   5. vision and coding options on every GPU tier
  # Sizes are download sizes from registry.ollama.ai; the GPU needs that plus
  # a few GB for the context. Re-check with scripts/check_models.sh.
  # VRAM: A5000 24 GB, 6000 Ada 48 GB, 6000 Blackwell 96 GB, GB10 128 GB shared.
  ollama_models = [
    # Every GPU (A5000 and up)
    { value = "gemma4:e4b", name = "Gemma 4 E4B", description = "6.6 GB - Google, vision, fast; every GPU (default)" },
    { value = "gemma4:e2b", name = "Gemma 4 E2B", description = "4.6 GB - Google, vision; smallest, for CPU-only workspaces" },
    { value = "qwen3.5:9b", name = "Qwen 3.5 9B", description = "6.6 GB - Alibaba, vision + thinking; every GPU" },
    { value = "gemma4:12b", name = "Gemma 4 12B", description = "8.0 GB - Google, vision, 256K context; every GPU" },
    { value = "ministral-3:14b", name = "Ministral 3 14B", description = "9.1 GB - Mistral, vision, efficient; every GPU" },
    { value = "gpt-oss:20b", name = "gpt-oss 20B", description = "13.8 GB - OpenAI open weights, reasoning; every GPU" },
    { value = "devstral-small-2:24b", name = "Devstral Small 2 24B", description = "15.2 GB - Mistral, built for coding agents, vision; every GPU" },
    { value = "qwen3.8:27b", name = "Qwen 3.8 27B", description = "17.7 GB - Alibaba, newest Qwen, coding + agents, vision; every GPU" },
    { value = "gemma4:26b", name = "Gemma 4 26B (MoE)", description = "18.7 GB - Google, vision, fast (4B active); every GPU" },
    # 6000 Ada and up
    { value = "glm-4.7-flash", name = "GLM 4.7 Flash (MoE)", description = "19.0 GB - Zhipu, thinking, strong for its size; 6000 Ada or larger" },
    { value = "gemma4:31b", name = "Gemma 4 31B", description = "20.4 GB - Google, strongest Gemma 4, vision; 6000 Ada or larger" },
    { value = "qwen3.6:35b", name = "Qwen 3.6 35B (MoE)", description = "22.6 GB - Alibaba, agentic coding, vision; 6000 Ada or larger" },
    # 6000 Blackwell and GB10
    { value = "qwen3-coder-next", name = "Qwen 3 Coder Next 80B (MoE)", description = "51.7 GB - Alibaba, coding agent; 6000 Blackwell or GB10" },
    { value = "gpt-oss:120b", name = "gpt-oss 120B", description = "65.4 GB - OpenAI open weights, reasoning; 6000 Blackwell or GB10" },
    { value = "qwen3.5:122b", name = "Qwen 3.5 122B", description = "81.4 GB - Alibaba, largest Qwen 3.5; GB10 (tight on 6000 Blackwell)" },
    { value = "nemotron-3-super:120b", name = "Nemotron 3 Super 120B", description = "86.8 GB - NVIDIA, multi-agent work, 12B active; GB10 only" },
    # Rule-4 exception: released 2026-10-15, pulls still ramping. Needs Ollama 0.40.5+.
    { value = "nemotron-3.5-super:120b", name = "Nemotron 3.5 Super VL 120B", description = "90.2 GB - NVIDIA, vision + agentic coding, 12B active; GB10 only" },
  ]

  # "" = no model; "custom" = the free-text model parameter.
  model = (
    data.coder_parameter.ollama_model.value == "none" ? "" :
    data.coder_parameter.ollama_model.value == "custom" ? trimspace(data.coder_parameter.custom_model[0].value) :
    data.coder_parameter.ollama_model.value
  )
}

data "coder_parameter" "ollama_model" {
  name         = "ollama_model"
  display_name = "Local model (Ollama)"
  description  = "Pulled at every workspace start onto the node's local disk (never NFS) and set as OpenCode's default. Change it and restart to switch."
  default      = "gemma4:e4b"
  icon         = "/emojis/1f999.png"
  mutable      = true
  form_type    = "dropdown"
  order        = 10

  dynamic "option" {
    for_each = local.ollama_models
    content {
      name        = option.value.name
      value       = option.value.value
      description = option.value.description
    }
  }
  option {
    name        = "Other (enter a name)"
    value       = "custom"
    description = "Any model from ollama.com/library"
  }
  option {
    name        = "None"
    value       = "none"
    description = "Start Ollama and OpenCode without pulling a model"
  }
}

data "coder_parameter" "custom_model" {
  count        = data.coder_parameter.ollama_model.value == "custom" ? 1 : 0
  name         = "custom_model"
  display_name = "Model name"
  description  = "Name and tag from ollama.com/library, e.g. qwen3.8:27b"
  type         = "string"
  default      = ""
  mutable      = true
  order        = 11
  validation {
    regex = "^[a-z0-9][a-z0-9._/-]*(:[A-Za-z0-9._-]+)?$"
    error = "Use an Ollama model name such as gemma4:12b"
  }
}

data "coder_parameter" "context_length" {
  name         = "context_length"
  display_name = "Context length"
  description  = "Ollama context window. OpenCode needs at least 64K; larger windows use more GPU memory."
  default      = "65536"
  icon         = "/emojis/1f4cf.png"
  mutable      = true
  order        = 12
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
  description  = "The number of CPU cores"
  default      = "4"
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
  description  = "The amount of memory in GB"
  default      = "8"
  icon         = "/icon/memory.svg"
  mutable      = true
  option {
    name  = "4 GB"
    value = "4"
  }
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
      curl -sf http://127.0.0.1:11434/api/ps | jq -r '.models[0] // empty | "\(.name) \(.size_vram * 100 / .size | floor)% GPU"' | grep . || echo "not loaded"
    EOT
    interval     = 15
    timeout      = 3
  }
}

resource "coder_script" "ollama_setup" {
  agent_id           = coder_agent.main.id
  display_name       = "RA-CODE (Ollama + OpenCode)"
  icon               = "/emojis/1f999.png"
  log_path           = "ollama_setup.log"
  run_on_start       = true
  start_blocks_login = false
  script = templatefile("${path.module}/scripts/ollama_setup.sh", {
    model            = local.model
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

        # Copy ollama and its CUDA libraries into the node-local volume.
        # The workspace image has no zstd for the upstream .tar.zst, and
        # the official image is multi-arch (x86 nodes and the ARM GB10).
        init_container {
          name              = "ollama-install"
          image             = local.ollama_image
          image_pull_policy = "IfNotPresent"
          security_context {
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }
          command = ["sh", "-c", "rm -rf /opt/llm/ollama && mkdir -p /opt/llm/ollama/bin /opt/llm/ollama/lib /opt/llm/models && cp /usr/bin/ollama /opt/llm/ollama/bin/ && cp -r /usr/lib/ollama /opt/llm/ollama/lib/"]
          resources {
            requests = {
              "cpu"    = "100m"
              "memory" = "128Mi"
            }
            limits = {
              "cpu"    = "2"
              "memory" = "1Gi"
            }
          }
          volume_mount {
            mount_path = "/opt/llm"
            name       = "llm"
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
            value = "/opt/llm/ollama/bin:/home/coder/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          }
          env {
            name  = "OLLAMA_MODELS"
            value = "/opt/llm/models"
          }
          env {
            name  = "OLLAMA_CONTEXT_LENGTH"
            value = data.coder_parameter.context_length.value
          }
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
            limits = local.limits
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

        # Ollama binary + models on the node's local disk, not NFS. Wiped
        # when the pod goes away, so the model is pulled again on start.
        volume {
          name = "llm"
          empty_dir {
            size_limit = "200Gi"
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