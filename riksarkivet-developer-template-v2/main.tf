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

data "coder_parameter" "nix_profile" {
  name         = "nix_profile"
  display_name = "Toolset Profile"
  description  = "Which Nix toolset to install. Mutable: change it and restart the workspace to switch profiles."
  type         = "string"
  default      = "dev"
  icon         = "/icon/nix.svg"
  mutable      = true
  form_type    = "radio"
  order        = 5

  option {
    name        = "Development"
    value       = "dev"
    description = "go, nodejs, gcc/make, kubectl, helm, terraform"
  }
  option {
    name        = "Data Science"
    value       = "datascience"
    description = "python 3.12 (numpy, pandas, polars, pyarrow, jupyterlab), uv, nodejs"
  }
  option {
    name        = "ML (GPU)"
    value       = "ml"
    description = "Data Science + PyTorch with CUDA - for GPU workspaces"
  }
  option {
    name        = "Local LLM (GPU)"
    value       = "llm"
    description = "ollama-cuda for GPU-accelerated local models - pair with a GPU"
  }
  option {
    name        = "Kubernetes Ops"
    value       = "ops"
    description = "kubectl, helm, k9s, argo, kustomize, kubectx, terraform, aws/azure CLIs"
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

data "coder_parameter" "local_model" {
  name         = "local_model"
  display_name = "Local Model (Ollama)"
  description  = "Pull a local LLM via Ollama and configure OpenCode to use it. Models are stored on the pod's local disk and re-downloaded on start."
  type         = "string"
  default      = "none"
  icon         = "/emojis/1f999.png"
  mutable      = true
  form_type    = "dropdown"
  order        = 50

  option {
    name        = "None"
    value       = "none"
    description = "No local model"
  }

  # --- Small (runs on CPU) ---
  option {
    name        = "Gemma 3 1B"
    value       = "gemma3:1b"
    description = "~0.8 GB, 32K context, runs on CPU"
  }
  option {
    name        = "Qwen 2.5 Coder 1.5B"
    value       = "qwen2.5-coder:1.5b"
    description = "~1 GB, runs on CPU"
  }
  option {
    name        = "Llama 3.2 3B"
    value       = "llama3.2:3b"
    description = "~2 GB, runs on CPU"
  }
  option {
    name        = "Phi 4 Mini 3.8B"
    value       = "phi4-mini"
    description = "~2.5 GB, runs on CPU"
  }

  # --- Medium (8-16 GB RAM) ---
  option {
    name        = "Gemma 3 4B"
    value       = "gemma3:4b"
    description = "~3.4 GB, 128K context, vision capable"
  }
  option {
    name        = "Code Llama 7B"
    value       = "codellama:7b"
    description = "~3.8 GB"
  }
  option {
    name        = "Mistral 7B"
    value       = "mistral:7b"
    description = "~4.1 GB"
  }
  option {
    name        = "Llama 3.1 8B"
    value       = "llama3.1:8b"
    description = "~4.7 GB"
  }
  option {
    name        = "Qwen 2.5 Coder 7B"
    value       = "qwen2.5-coder:7b"
    description = "~4.7 GB, 8+ GB RAM recommended"
  }
  option {
    name        = "DeepSeek R1 8B"
    value       = "deepseek-r1:8b"
    description = "~4.9 GB, reasoning model"
  }
  option {
    name        = "Qwen 3 8B"
    value       = "qwen3:8b"
    description = "~5.2 GB"
  }
  option {
    name        = "Gemma 3 12B"
    value       = "gemma3:12b"
    description = "~8.2 GB, 128K context, 16+ GB RAM recommended"
  }
  option {
    name        = "DeepSeek Coder V2 16B"
    value       = "deepseek-coder-v2:16b"
    description = "~8.9 GB, MoE coding model"
  }
  option {
    name        = "Phi 4 14B"
    value       = "phi4:14b"
    description = "~9.1 GB"
  }
  option {
    name        = "Qwen 2.5 Coder 14B"
    value       = "qwen2.5-coder:14b"
    description = "~9 GB, 16+ GB RAM recommended"
  }
  option {
    name        = "Devstral 24B"
    value       = "devstral"
    description = "~14 GB, Mistral's agentic coding model"
  }

  # --- Large (GPU workspace strongly recommended) ---
  option {
    name        = "Gemma 3 27B"
    value       = "gemma3:27b"
    description = "~17 GB, 128K context, GPU strongly recommended"
  }
  option {
    name        = "Qwen 3 Coder 30B"
    value       = "qwen3-coder:30b"
    description = "~19 GB, MoE, GPU strongly recommended"
  }
  option {
    name        = "DeepSeek R1 32B"
    value       = "deepseek-r1:32b"
    description = "~19 GB, reasoning, GPU strongly recommended"
  }
  option {
    name        = "Qwen 3 32B"
    value       = "qwen3:32b"
    description = "~20 GB, GPU strongly recommended"
  }
  option {
    name        = "Llama 3.3 70B"
    value       = "llama3.3:70b"
    description = "~43 GB, GPU workspace with 64+ GB RAM required"
  }
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
    "nix_profile"              = "ml"
  }
}

data "coder_workspace_preset" "standard-ds" {
  name        = "Standard Data Science"
  description = "Data science work with the Python/PyData toolset (without GPU)"
  icon        = "/emojis/1f435.png"
  parameters = {
    "cpu"                      = "8"
    "memory"                   = "32"
    "home_disk_size"           = "100"
    "shared_memory_percentage" = "20"
    "gpu_type"                 = "None"
    "enable_advanced_tools"    = "false"
    "nix_profile"              = "datascience"
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
    "nix_profile"              = "dev"
  }
}

data "coder_workspace_preset" "local-llm-medium" {
  name        = "Local LLM (Medium)"
  description = "GPU workspace for local models up to ~14B - comes with Gemma 3 12B"
  icon        = "/emojis/1f999.png"
  parameters = {
    "cpu"                      = "8"
    "memory"                   = "48"
    "home_disk_size"           = "100"
    "shared_memory_percentage" = "20"
    "gpu_type"                 = "NVIDIA-RTX-A5000"
    "enable_advanced_tools"    = "false"
    "nix_profile"              = "llm"
    "local_model"              = "gemma3:12b"
  }
}

data "coder_workspace_preset" "local-llm-large" {
  name        = "Local LLM (Large)"
  description = "GPU workspace for large local models - comes with Qwen 3 Coder 30B"
  icon        = "/emojis/1f999.png"
  parameters = {
    "cpu"                      = "20"
    "memory"                   = "96"
    "home_disk_size"           = "200"
    "shared_memory_percentage" = "30"
    "gpu_type"                 = "NVIDIA-RTX-6000-Ada-Generation"
    "gpu_count"                = "1"
    "enable_advanced_tools"    = "true"
    "nix_profile"              = "llm"
    "local_model"              = "qwen3-coder:30b"
  }
}

data "coder_workspace_preset" "kubernetes-ops" {
  name        = "Kubernetes Ops"
  description = "Cluster operations toolset: kubectl, helm, k9s, argo, cloud CLIs"
  icon        = "/emojis/2638-fe0f.png"
  parameters = {
    "cpu"                      = "4"
    "memory"                   = "16"
    "home_disk_size"           = "50"
    "shared_memory_percentage" = "20"
    "gpu_type"                 = "None"
    "enable_advanced_tools"    = "true"
    "nix_profile"              = "ops"
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
    "nix_profile"              = "dev"
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

  # Shows the selected local model and whether it can actually use a GPU.
  dynamic "metadata" {
    for_each = data.coder_parameter.local_model.value != "none" ? [1] : []
    content {
      display_name = "Local Model"
      key          = "8_local_model"
      interval     = 60
      timeout      = 5
      script       = <<-EOT
        if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
          echo "${data.coder_parameter.local_model.value} @ GPU ✔"
        else
          echo "${data.coder_parameter.local_model.value} @ CPU ⚠ (no GPU)"
        fi
      EOT
    }
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
      elif [ -e "$HOME/.nix-profile/bin/starship" ]; then
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
      nix_profile   = data.coder_parameter.nix_profile.value
    }),
    "\r",
    ""
  )
}

resource "coder_script" "ollama_setup" {
  count              = data.coder_parameter.local_model.value != "none" ? 1 : 0
  agent_id           = coder_agent.main.id
  display_name       = "Ollama Local Model"
  icon               = "/emojis/1f999.png"
  log_path           = "ollama_setup.log"
  run_on_start       = true
  start_blocks_login = false

  script = replace(
    templatefile("${path.module}/scripts/ollama_setup.sh", {
      ollama_model = data.coder_parameter.local_model.value
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
