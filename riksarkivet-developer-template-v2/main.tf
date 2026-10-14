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

provider "coder" {}

provider "kubernetes" {
  # Authenticate via ~/.kube/config or a Coder-specific ServiceAccount, depending on admin preferences
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

# ========================================
# Variables
# ========================================

variable "use_kubeconfig" {
  type        = bool
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces. A valid "~/.kube/config" must be present on the Coder host.
  EOF
  default     = false
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to create workspaces in (must exist prior to creating workspaces)."
  default     = "coder"
}

variable "claude_code_oauth_token" {
  description = "OAuth token passed to Claude Code via the CLAUDE_CODE_OAUTH_TOKEN env var. Generate one with `claude setup-token`."
  type        = string
  default     = ""
  sensitive   = true
}

# ========================================
# Data Sources
# ========================================

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# ========================================
# Locals
# ========================================

locals {
  git_author_email = data.coder_workspace_owner.me.email

  # --- GPU Logic ---
  selected_gpu = data.coder_parameter.gpu_type.value
  # Handle conditional GPU count parameter - only exists for Ada Generation GPUs
  selected_gpu_count_param = data.coder_parameter.gpu_type.value == "NVIDIA-RTX-6000-Ada-Generation" ? data.coder_parameter.gpu_count[0].value : "1"
  # For non-Ada GPUs, default to 1 GPU if not "None"
  actual_gpu_count = (local.selected_gpu == "None" || local.selected_gpu == "") ? 0 : tonumber(local.selected_gpu_count_param)
  gpu_resources    = local.actual_gpu_count > 0 ? { "nvidia.com/gpu" = format("%d", local.actual_gpu_count) } : {}
  gpu_label_key    = "nvidia.com/gpu.product"

  gpu_types = [
    { name = "None", value = "None", description = "CPU-only workspace" },
    { name = "Quadro RTX 5000", value = "Quadro-RTX-5000", description = "Professional graphics, 16GB VRAM" },
    { name = "NVIDIA RTX A5000", value = "NVIDIA-RTX-A5000", description = "Workstation GPU, 24GB VRAM" },
    { name = "NVIDIA RTX 6000 Ada Generation", value = "NVIDIA-RTX-6000-Ada-Generation", description = "Latest generation, 48GB VRAM" }
  ]

  # Only for NVIDIA RTX 6000 Ada Generation
  ada_gpu_count_options = [
    { name = "1 GPU", value = "1", description = "Single Ada GPU for development" },
    { name = "2 GPUs", value = "2", description = "Dual Ada GPU setup" }
  ]
}

# ========================================
# Parameters
# ========================================

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "Number of CPU cores for the workspace"
  type         = "number"
  default      = 4
  icon         = "/icon/memory.svg"
  mutable      = true
  form_type    = "slider"
  order        = 1

  validation {
    min   = 1
    max   = 36
    error = "CPU cores must be between {min} and {max}"
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (RAM)"
  description  = "Amount of memory in GB for the workspace"
  type         = "number"
  default      = 16
  icon         = "/icon/memory.svg"
  mutable      = true
  form_type    = "slider"
  order        = 2

  validation {
    min   = 3
    max   = 180
    error = "Memory must be between {min} and {max} GB"
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "The size of the home disk in GB"
  default      = "10"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false
  order        = 3
  validation {
    min = 1
    max = 99999
  }
}

data "coder_parameter" "shared_memory_percentage" {
  name         = "shared_memory_percentage"
  display_name = "Shared Memory Allocation"
  description  = "Percentage of RAM to allocate to shared memory (/dev/shm). This is reserved memory that gets released automatically when not in use."
  type         = "number"
  default      = 20
  icon         = "/icon/memory.svg"
  mutable      = true
  form_type    = "slider"
  order        = 4

  validation {
    min   = 0
    max   = 80
    error = "Shared memory must be between {min}% and {max}% of total RAM"
  }
}

# --- GPU Configuration ---
data "coder_parameter" "gpu_type" {
  name         = "gpu_type"
  display_name = "GPU Type"
  description  = "Select GPU type for ML/AI workloads"
  type         = "string"
  default      = "None"
  icon         = "/emojis/26a1.png"
  mutable      = false
  form_type    = "dropdown"
  order        = 10

  dynamic "option" {
    for_each = local.gpu_types
    content {
      name        = option.value.name
      value       = option.value.value
      description = option.value.description
    }
  }
}

data "coder_parameter" "gpu_count" {
  # Only show if GPU type is "NVIDIA RTX 6000 Ada Generation"
  count        = data.coder_parameter.gpu_type.value == "NVIDIA-RTX-6000-Ada-Generation" ? 1 : 0
  name         = "gpu_count"
  display_name = "Number of Ada GPUs"
  description  = "Number of NVIDIA RTX 6000 Ada Generation GPUs to allocate"
  type         = "string"
  default      = "1"
  icon         = "/emojis/0023-fe0f-20e3.png"
  mutable      = false
  form_type    = "radio"
  order        = 12

  dynamic "option" {
    for_each = local.ada_gpu_count_options
    content {
      name        = option.value.name
      value       = option.value.value
      description = option.value.description
    }
  }
}

# --- API Keys & Tokens (conditional) ---
data "coder_parameter" "enable_advanced_tools" {
  name         = "enable_advanced_tools"
  display_name = "Enable Advanced Development Tools"
  description  = "Enable additional API tokens and SSH configuration"
  type         = "bool"
  default      = false
  form_type    = "checkbox"
  order        = 40
}

data "coder_parameter" "gh_token" {
  count        = data.coder_parameter.enable_advanced_tools.value ? 1 : 0
  name         = "gh_token"
  display_name = "GitHub Token"
  description  = "GitHub personal access token for repository access"
  type         = "string"
  default      = ""
  mutable      = true
  form_type    = "input"
  order        = 41

  styling = jsonencode({
    mask_input  = true
    placeholder = "ghp_..."
  })
}

data "coder_parameter" "hf_token" {
  count        = data.coder_parameter.enable_advanced_tools.value ? 1 : 0
  name         = "hf_token"
  display_name = "Hugging Face Token"
  description  = "Hugging Face access token for model downloads"
  type         = "string"
  default      = ""
  mutable      = true
  form_type    = "input"
  order        = 42

  styling = jsonencode({
    mask_input  = true
    placeholder = "hf_..."
  })
}

data "coder_parameter" "ssh_private_key" {
  count        = data.coder_parameter.enable_advanced_tools.value ? 1 : 0
  name         = "ssh_private_key"
  display_name = "SSH Private Key"
  description  = "SSH private key for Git repository access (optional)"
  type         = "string"
  default      = ""
  mutable      = true
  form_type    = "textarea"
  order        = 43

  styling = jsonencode({
    placeholder = "-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----"
  })
}

# ========================================
# Workspace Presets
# ========================================

data "coder_workspace_preset" "intense-ml" {
  name        = "Intense ML Training"
  description = "High-performance configuration for intensive ML/AI training with dual Ada GPUs"
  icon        = "/emojis/1f916.png"
  parameters = {
    "cpu"                      = "20"
    "memory"                   = "96"
    "home_disk_size"           = "500"
    "shared_memory_percentage" = "60"
    "gpu_type"                 = "NVIDIA-RTX-6000-Ada-Generation"
    "gpu_count"                = "2"
    "enable_advanced_tools"    = "true"
  }
}

data "coder_workspace_preset" "standard-ds" {
  name        = "Standard Data Science"
  description = "Standard configuration for general development work (without GPU)"
  icon        = "/emojis/1f435.png"
  parameters = {
    "cpu"                      = "8"
    "memory"                   = "32"
    "home_disk_size"           = "100"
    "shared_memory_percentage" = "20"
    "gpu_type"                 = "None"
    "enable_advanced_tools"    = "false"
  }
}

data "coder_workspace_preset" "standard-dev" {
  name        = "Standard Development"
  description = "CI + general development work (without GPU)"
  icon        = "/emojis/1f435.png"
  parameters = {
    "cpu"                      = "8"
    "memory"                   = "32"
    "home_disk_size"           = "100"
    "shared_memory_percentage" = "20"
    "gpu_type"                 = "None"
    "enable_advanced_tools"    = "true"
  }
}

data "coder_workspace_preset" "small-dev" {
  name        = "Small Development"
  description = "CI + general development work (without GPU)"
  icon        = "/emojis/1f435.png"
  parameters = {
    "cpu"                      = "2"
    "memory"                   = "4"
    "home_disk_size"           = "10"
    "shared_memory_percentage" = "50"
    "gpu_type"                 = "None"
    "enable_advanced_tools"    = "false"
  }
}

# ========================================
# Coder Agent
# ========================================

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"

  startup_script = <<-EOT
    set -e

    # Add any commands that should be executed at workspace startup (e.g install requirements, start a program, etc) here
  EOT

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
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

  # Shows live Nix toolset install progress by parsing the setup log:
  # current package being downloaded + total store size, or "ready".
  metadata {
    display_name = "Dev Environment (Nix)"
    key          = "9_nix_status"
    interval     = 15
    timeout      = 3
    script       = <<-EOT
      LOG=/tmp/nix_setup.log
      if pgrep -f "nix profile install" >/dev/null 2>&1; then
        SIZE=$(du -sh /nix/store 2>/dev/null | cut -f1)
        PKG=$(grep "copying path" "$LOG" 2>/dev/null | tail -1 | sed -E "s|^copying path '/nix/store/[a-z0-9]+-([^']*)'.*|\1|")
        if [ -n "$PKG" ]; then
          echo "⏳ $PKG ($SIZE)"
        else
          echo "⏳ preparing… ($SIZE)"
        fi
      elif [ -e "$HOME/.nix-profile/bin/terraform" ]; then
        echo "ready ✔"
      else
        echo "pending"
      fi
    EOT
  }

  dynamic "metadata" {
    for_each = local.actual_gpu_count > 0 ? range(local.actual_gpu_count) : []
    content {
      display_name = "GPU ${metadata.value} Memory"
      key          = "gpu_${metadata.value}_memory"
      script       = <<EOT
        if command -v nvidia-smi >/dev/null 2>&1; then
          nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits --id=${metadata.value} | awk -F', ' '{
            used=$1; total=$2;
            if (total > 0) {
              percent=int((used/total)*100);
              printf "%.1f/%.1fGB (%d%%)", used/1024, total/1024, percent
            } else {
              print "N/A"
            }
          }'
        else
          echo "nvidia-smi not available"
        fi
      EOT
      interval     = 10
      timeout      = 5
    }
  }
}

# ========================================
# Coder Apps (Modules)
# ========================================

module "claude-code" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/claude-code/coder"
  version                 = "5.2.0"
  agent_id                = coder_agent.main.id
  anthropic_api_key       = ""
  claude_binary_path      = "$HOME/.local/bin"
  claude_code_oauth_token = var.claude_code_oauth_token
  claude_code_version     = "latest"
  disable_autoupdater     = false
  enable_ai_gateway       = false
  icon                    = "/icon/claude.svg"
  install_claude_code     = true
  mcp                     = ""
  model                   = ""
  post_install_script     = null
  pre_install_script      = null
  workdir                 = null
}

module "vscode-web" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/vscode-web/coder"
  version                 = "1.5.0"
  agent_id                = coder_agent.main.id
  accept_license          = true
  auto_install_extensions = false
  commit_id               = ""
  disable_trust           = false
  extensions_dir          = ""
  folder                  = ""
  offline                 = false
  platform                = ""
  port                    = 13338
  subdomain               = false
  telemetry_level         = "error"
  use_cached              = false
  workspace               = ""
}

module "zed" {
  count      = data.coder_workspace.me.start_count
  source     = "registry.coder.com/coder/zed/coder"
  version    = "1.1.4"
  agent_id   = coder_agent.main.id
  agent_name = ""
  folder     = ""
  settings   = ""
}

module "git-config" {
  count                 = data.coder_workspace.me.start_count
  source                = "registry.coder.com/coder/git-config/coder"
  version               = "1.0.33"
  agent_id              = coder_agent.main.id
  allow_email_change    = false
  allow_username_change = true
}

module "dotfiles" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/dotfiles/coder"
  version                 = "1.4.2"
  agent_id                = coder_agent.main.id
  default_dotfiles_branch = ""
  default_dotfiles_uri    = "https://github.com/AI-Riksarkivet/dotfiles"
  description             = "Enter a URL for a [dotfiles repository](https://dotfiles.github.io) to personalize your workspace. Use an SSH URL (e.g. `git@host:user/repo`) if your Git provider restricts HTTPS cloning."
  dotfiles_branch         = null
  dotfiles_uri            = null
  manual_update           = false
  post_clone_script       = null
  user                    = null
}

module "filebrowser" {
  count         = data.coder_workspace.me.start_count
  source        = "registry.coder.com/coder/filebrowser/coder"
  version       = "1.1.5"
  agent_id      = coder_agent.main.id
  agent_name    = "main"
  database_path = "filebrowser.db"
  folder        = "~"
  port          = 13339
  subdomain     = false
}

module "git-commit-signing" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-commit-signing/coder"
  version  = "1.0.32"
  agent_id = coder_agent.main.id
}

module "coder-login" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "1.1.1"
  agent_id = coder_agent.main.id
}

# ========================================
# Kubernetes Resources
# ========================================

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace
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
    namespace = var.namespace
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
        "com.coder.workspace.name"   = data.coder_workspace.me.name
        "com.coder.user.id"          = data.coder_workspace_owner.me.id
        "com.coder.user.username"    = data.coder_workspace_owner.me.name
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
        runtime_class_name = local.actual_gpu_count > 0 ? "nvidia" : null

        node_selector = {
          "kubernetes.io/arch" = "amd64"
        }

        security_context {
          fs_group = 1000
        }

        # Prepare a persistent /nix store (on the home PVC, owned by coder)
        # before the non-root workspace container starts.
        init_container {
          name              = "nix-store-init"
          image             = "codercom/example-base:ubuntu"
          image_pull_policy = "IfNotPresent"
          command           = ["sh", "-c", "mkdir -p /nix && chown 1000:1000 /nix"]
          security_context {
            run_as_user     = "0"
            run_as_non_root = false
          }
          volume_mount {
            mount_path = "/nix"
            name       = "home"
            sub_path   = "nix"
          }
        }

        container {
          name              = "dev"
          image             = "codercom/example-base:ubuntu"
          image_pull_policy = "Always"
          command           = ["sh", "-c", coder_agent.main.init_script]
          security_context {
            run_as_user     = "1000"
            run_as_non_root = true
          }
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }
          env {
            name  = "GH_TOKEN"
            value = data.coder_parameter.enable_advanced_tools.value && length(data.coder_parameter.gh_token) > 0 ? data.coder_parameter.gh_token[0].value : ""
          }
          env {
            name  = "HF_TOKEN"
            value = data.coder_parameter.enable_advanced_tools.value && length(data.coder_parameter.hf_token) > 0 ? data.coder_parameter.hf_token[0].value : ""
          }
          resources {
            requests = merge({
              "cpu"    = "250m"
              "memory" = "512Mi"
            }, local.gpu_resources)
            limits = merge({
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }, local.gpu_resources)
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }

          # Persistent Nix store (lives on the home PVC)
          volume_mount {
            mount_path = "/nix"
            name       = "home"
            sub_path   = "nix"
            read_only  = false
          }

          volume_mount {
            mount_path = "/dev/shm"
            name       = "dshm"
            read_only  = false
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.home.metadata.0.name
            read_only  = false
          }
        }

        volume {
          name = "dshm"
          empty_dir {
            medium     = "Memory"
            size_limit = "${floor(tonumber(data.coder_parameter.memory.value) * (data.coder_parameter.shared_memory_percentage.value / 100))}Gi"
          }
        }

        affinity {
          // Pin GPU workspaces to nodes with the selected GPU model.
          dynamic "node_affinity" {
            for_each = local.selected_gpu != "None" && local.selected_gpu != "" ? [1] : []
            content {
              required_during_scheduling_ignored_during_execution {
                node_selector_term {
                  match_expressions {
                    key      = local.gpu_label_key
                    operator = "In"
                    values   = [local.selected_gpu]
                  }
                }
              }
            }
          }

          // This affinity attempts to spread out all workspace pods evenly across
          // nodes.
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

# ========================================
# Coder Resource Metadata
# ========================================

resource "coder_metadata" "resources" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_deployment_v1.main[0].id
  icon        = "/emojis/1f9be.png"

  item {
    key   = "volume_claim"
    value = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
  }

  item {
    key   = "gpu_type"
    value = local.selected_gpu == "None" ? "No GPU" : local.selected_gpu
  }
}

# ========================================
# Coder Resource Scripts
# ========================================

resource "coder_script" "nix_setup" {
  agent_id           = coder_agent.main.id
  display_name       = "Nix Dev Environment"
  icon               = "/icon/nix.svg"
  log_path           = "nix_setup.log"
  run_on_start       = true
  start_blocks_login = false

  script = replace(
    templatefile("${path.module}/scripts/nix_setup.sh", {
      flake_nix_b64 = base64encode(file("${path.module}/flake.nix"))
    }),
    "\r",
    ""
  )
}

resource "coder_script" "ssh_setup" {
  agent_id           = coder_agent.main.id
  display_name       = "SSH Key Setup"
  icon               = "/icon/terminal.svg"
  log_path           = "ssh_setup.log"
  run_on_start       = true
  start_blocks_login = false

  script = replace(
    templatefile("${path.module}/scripts/ssh_config.sh", {
      git_author_email = local.git_author_email
      ssh_private_key  = data.coder_parameter.enable_advanced_tools.value && length(data.coder_parameter.ssh_private_key) > 0 ? data.coder_parameter.ssh_private_key[0].value : ""
    }),
    "\r",
    ""
  )
}
