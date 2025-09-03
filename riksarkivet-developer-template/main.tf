terraform {
  required_providers {
    coder = {
      source = "coder/coder"
      version = ">=2.4.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "coder" {}

provider "kubernetes" {
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

# ========================================
# Variable
# ========================================

variable "use_kubeconfig" {
  type        = bool
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces.  A valid "~/.kube/config" must be present on the Coder host.
  EOF
  default     = false
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to create workspaces in (must exist prior to creating workspaces)."
  default     = "coder"
}

variable "image_registry" {
  type        = string
  description = "Container registry URL (e.g., docker.io, ghcr.io, registry:5000)"
  default     = "docker.io"
}

variable "temp_ip" {
  type        = string
  description = "The Kubernetes iP."
  default     = "http://10.100.127.31:30256"

}

variable "mlflow_external_address" {
  type        = string
  description = "The external address for the MLflow Tracking Server UI (e.g., http://mlflow.example.com or http://<IP>:<Port>). Leave empty to disable the MLflow App and environment variable injection."
  default     = "http://10.100.127.31:30025"
}

variable "argowf_external_address" {
  type        = string
  description = "The external address for the Argo Workflow Server UI (e.g., http://argo.example.com or http://<IP>:<Port>). Leave empty to disable the Argo Workflow App and environment variable injection."
  default     = "http://10.100.127.31:32746"
}

variable "docker_registry_secret" {
  type        = string
  description = "The name of the Kubernetes secret containing Docker registry credentials for pulling private images."
  default     = "dockerhub-secret"
}

variable "image_repository" {
  type        = string
  description = "Container image repository name (e.g., riksarkivet/workspace-developer)"
  default     = "riksarkivet/workspace-developer"
}

variable "image_tag" {
  type        = string
  description = "Container image tag"
  default     = "latest"
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
  git_author_name  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  git_author_email = data.coder_workspace_owner.me.email

  # --- Images ---
  main_image = local.actual_gpu_count > 0 ? "${var.image_registry}/${var.image_repository}:${var.image_tag}" : "${var.image_registry}/${var.image_repository}:${var.image_tag}${endswith(var.image_tag, "-cpu") ? "" : "-cpu"}"

  # --- GPU Logic ---
  selected_gpu             = data.coder_parameter.gpu_type.value
  # Handle conditional GPU count parameter - only exists for Ada Generation GPUs
  selected_gpu_count_param = data.coder_parameter.gpu_type.value == "NVIDIA-RTX-6000-Ada-Generation" ? data.coder_parameter.gpu_count[0].value : "1"
  # For non-Ada GPUs, default to 1 GPU if not "None"
  actual_gpu_count         = (local.selected_gpu == "None" || local.selected_gpu == "") ? 0 : tonumber(local.selected_gpu_count_param)
  gpu_resources            = local.actual_gpu_count > 0 ? { "nvidia.com/gpu" = format("%d", local.actual_gpu_count) } : {}
  gpu_label_key            = "nvidia.com/gpu.product"

  # --- External Service Environment Variables ---
  internal_service_env_vars = merge(
    var.mlflow_external_address != "" ? { "MLFLOW_TRACKING_URI" = var.mlflow_external_address } : {},
    var.argowf_external_address != "" ? { "ARGO_BASE_HREF" = var.argowf_external_address } : {},
  )

  # Define the LakeFS secret name
  lakefs_secret_name = "lakefs-secrets"

  # --- Dagger Engine Resources (configurable and conditional) ---
  dagger_enabled      = data.coder_parameter.use_dagger.value
  dagger_cpu_limit    = local.dagger_enabled && length(data.coder_parameter.dagger_cpu_limit) > 0 ? data.coder_parameter.dagger_cpu_limit[0].value : 2
  dagger_memory_limit = local.dagger_enabled && length(data.coder_parameter.dagger_memory_limit) > 0 ? data.coder_parameter.dagger_memory_limit[0].value : 8
  dagger_cpu_request  = "${floor(local.dagger_cpu_limit * 250)}m"    # 25% of limit in millicores
  dagger_memory_request = "${floor(local.dagger_memory_limit * 0.25)}Gi"  # 25% of limit

  # --- Check if running in CI mode ---
  is_ci = data.coder_parameter.is_ci.value
  
  # --- Parameter Options for Readability ---
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
# Workspace Presets
# ========================================

data "coder_workspace_preset" "intense-ml" {
  name        = "Intense ML Training"
  description = "High-performance configuration for intensive ML/AI training with dual Ada GPUs and Dagger"
  icon        = "/emojis/1f916.png"  # Fire emoji
  parameters = {
    "cpu"                      = "20"
    "memory"                   = "96"
    "home_disk_size"           = "500"
    "shared_memory_percentage" = "60"
    "gpu_type"                 = "NVIDIA-RTX-6000-Ada-Generation"
    "use_dagger"               = "true"
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
    "use_dagger"               = "false"
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
    "use_dagger"               = "true"
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
    "use_dagger"               = "true"
    "enable_advanced_tools"    = "false"
  }
}




# ========================================
# Parameters
# ========================================

# --- Resource Parameters ---
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
  display_name = "Home Disk Size"
  description  = "Size of the persistent home directory in GB"
  type         = "number"
  default      = 100
  icon         = "/emojis/1f4be.png"
  mutable      = false
  form_type    = "slider"
  order        = 3

  validation {
    min   = 5
    max   = 1000
    error = "Disk size must be between {min} and {max} GB"
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

# --- CI Mode Configuration ---
data "coder_parameter" "is_ci" {
  name         = "is_ci"
  display_name = "CI Mode"
  description  = "Enable CI mode (disables work/scratch mounts for testing)"
  type         = "bool"
  default      = false
  form_type    = "checkbox"
  mutable      = false
  order        = 15
}

# --- Development Tools Configuration ---
data "coder_parameter" "ai_prompt" {
  name        = "AI Prompt"
  display_name = "AI Assistant Prompt"
  description = "Custom prompt for Claude Code AI assistant"
  type        = "string"
  default     = ""
  mutable     = true
  form_type   = "textarea"
  order       = 20
  
  styling = jsonencode({
    placeholder = "Enter your custom AI prompt or leave empty for default behavior..."
  })
}



data "coder_parameter" "use_dagger" {
  name         = "use_dagger"
  display_name = "Use Dagger Engine"
  description  = "Enable Dagger container build system as a sidecar. Dagger provides containerized build capabilities without Docker. Requires additional CPU and memory resources. Note that the meomery is shared between the dagger and main container in the pod."
  type         = "bool"
  default      = false
  form_type    = "checkbox"
  mutable     = false
  order        = 30
}

data "coder_parameter" "dagger_cloud_token" {
  count       = data.coder_parameter.use_dagger.value ? 1 : 0
  name        = "dagger_cloud_token"
  display_name = "Docker Cloud Token"
  description = "For Dagger Traces and debugg"
  type        = "string"
  default     = ""
  mutable     = true
  form_type   = "input"
  order       = 31
  
  styling = jsonencode({
    mask_input  = true
    placeholder = "..."
  })
}

# --- Dagger Engine Resource Configuration (conditional) ---
data "coder_parameter" "dagger_cpu_limit" {
  count       = data.coder_parameter.use_dagger.value ? 1 : 0
  name        = "dagger_cpu_limit"
  display_name = "Dagger Engine CPU"
  description = "CPU cores for Dagger engine sidecar (additive to main container)"
  type        = "number"
  default     = 2
  mutable     = true
  form_type   = "slider"
  order       = 32
  
  validation {
    min   = 2
    max   = 24
    error = "Dagger CPU must be between {min} and {max} cores"
  }
}

data "coder_parameter" "dagger_memory_limit" {
  count       = data.coder_parameter.use_dagger.value ? 1 : 0
  name        = "dagger_memory_limit"
  display_name = "Dagger Engine Memory"
  description = "Memory for Dagger engine sidecar in GB (additive to main container)"
  type        = "number"
  default     = 8
  mutable     = true
  form_type   = "slider"
  order       = 33
  
  validation {
    min   = 8
    max   = 128
    error = "Dagger memory must be between {min} and {max} GB"
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

data "coder_parameter" "anthropic_api_key" {
  count       = data.coder_parameter.enable_advanced_tools.value ? 1 : 0
  name        = "anthropic_api_key"
  display_name = "Anthropic API Key"
  description = "Your Anthropic API key for Claude Code integration"
  type        = "string"
  default     = ""
  mutable     = true
  form_type   = "input"
  order       = 41
  
  styling = jsonencode({
    mask_input  = true
    placeholder = "sk-ant-api03-..."
  })
}

data "coder_parameter" "gh_token" {
  count       = data.coder_parameter.enable_advanced_tools.value ? 1 : 0
  name        = "gh_token"
  display_name = "GitHub Token"
  description = "GitHub personal access token for repository access"
  type        = "string"
  default     = ""
  mutable     = true
  form_type   = "input"
  order       = 42
  
  styling = jsonencode({
    mask_input  = true
    placeholder = "ghp_..."
  })
}

data "coder_parameter" "hf_token" {
  count       = data.coder_parameter.enable_advanced_tools.value ? 1 : 0
  name        = "hf_token"
  display_name = "Hugging Face Token"
  description = "Hugging Face access token for model downloads"
  type        = "string"
  default     = ""
  mutable     = true
  form_type   = "input"
  order       = 43
  
  styling = jsonencode({
    mask_input  = true
    placeholder = "hf_..."
  })
}


data "coder_parameter" "docker_password" {
  count       = data.coder_parameter.enable_advanced_tools.value ? 1 : 0
  name        = "docker_password"
  display_name = "Docker Registry Password"
  description = "Password/token for pushing to Docker registries"
  type        = "string"
  default     = ""
  mutable     = true
  form_type   = "input"
  order       = 45
  
  styling = jsonencode({
    mask_input  = true
    placeholder = "Enter Docker Hub password or token"
  })
}

data "coder_parameter" "ssh_private_key" {
  count       = data.coder_parameter.enable_advanced_tools.value ? 1 : 0
  name        = "ssh_private_key"
  display_name = "SSH Private Key"
  description = "SSH private key for Git repository access (optional)"
  type        = "string"
  default     = ""
  mutable     = true
  form_type   = "textarea"
  order       = 46
  
  styling = jsonencode({
    placeholder = "-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----"
  })
}

# ========================================
# Coder Agent Configuration
# ========================================

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"

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
    script       = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $$1 }'` `nproc`" | awk '{ printf "%0.2f", $$1/$$2 }'
    EOT
    interval     = 60
    timeout      = 1
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

  metadata {
    display_name = "Node Info"
    key          = "7_node_info"
    script       = <<EOT
      kubectl describe pod $HOSTNAME | grep "^Node:" | awk '{print $NF}'
    EOT
    interval     = 600
    timeout      = 5
  }

  metadata {
    display_name = "Pod IP"
    key          = "8_pod_ip"
    script       = <<EOT
      kubectl describe pod $HOSTNAME | grep "^IP:" | awk '{print $NF}'
    EOT
    interval     = 600
    timeout      = 5
  }

  display_apps {
    vscode                    = false
    vscode_insiders          = false
    ssh_helper               = false
    port_forwarding_helper   = false
    web_terminal             = true
  }
}

# ========================================
# Coder Apps
# ========================================
module "code-server" {
  count      = data.coder_workspace.me.start_count
  source     = "registry.coder.com/coder/code-server/coder"
  version    = "1.3.1"
  agent_id   = coder_agent.main.id
  use_cached = true
  subdomain     = false
}

module "filebrowser" {
  count         = data.coder_workspace.me.start_count
  source        = "registry.coder.com/modules/filebrowser/coder"
  version       = "1.0.30"
  agent_id      = coder_agent.main.id
  subdomain     = false
  database_path = ".config/filebrowser.db"
  folder        = "/"
}

module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/dotfiles/coder"
  version  = "1.0.29"
  default_dotfiles_uri = "https://github.com/AI-Riksarkivet/dotfiles"
  agent_id = coder_agent.main.id
}

module "coder-login" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "1.0.31"
  agent_id = coder_agent.main.id
}

module "claude-code" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/modules/claude-code/coder"
  version             = "2.2.0"
  agentapi_version    = "v0.6.1"
  agent_id            = coder_agent.main.id
  folder              = "/home/coder"
  install_claude_code = true
  subdomain           = false

  # Enable experimental features
  experiment_report_tasks = true
}

# ========================================
# Kubernetes Resources
# ========================================

# --- Kubernetes Persistent Volume Claim ---
resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "coder-pvc"
      "app.kubernetes.io/instance"   = "coder-pvc-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"    = "coder"
      "com.coder.resource"           = "true"
      "com.coder.workspace.id"       = data.coder_workspace.me.id
      "com.coder.workspace.name"     = data.coder_workspace.me.name
      "com.coder.user.id"            = data.coder_workspace_owner.me.id
      "com.coder.user.username"      = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
      }
    }
  }
}

# --- Kubernetes Deployment for the Workspace Pod ---
resource "kubernetes_deployment" "main" {
  count      = data.coder_workspace.me.start_count
  wait_for_rollout = false
  depends_on = [kubernetes_persistent_volume_claim.home]

  metadata {
    name      = "coder-${data.coder_workspace.me.id}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "coder-workspace"
      "app.kubernetes.io/instance"   = "coder-workspace-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"    = "coder"
      "com.coder.resource"           = "true"
      "com.coder.workspace.id"       = data.coder_workspace.me.id
      "com.coder.workspace.name"     = data.coder_workspace.me.name
      "com.coder.user.id"            = data.coder_workspace_owner.me.id
      "com.coder.user.username"      = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "com.coder.workspace.id" = data.coder_workspace.me.id
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = "coder-workspace"
          "app.kubernetes.io/instance"   = "coder-workspace-${data.coder_workspace.me.id}"
          "app.kubernetes.io/part-of"    = "coder"
          "com.coder.resource"           = "true"
          "com.coder.workspace.id"       = data.coder_workspace.me.id
          "com.coder.workspace.name"     = data.coder_workspace.me.name
          "com.coder.user.id"            = data.coder_workspace_owner.me.id
          "com.coder.user.username"      = data.coder_workspace_owner.me.name
        }
      }
      
      spec {
        runtime_class_name                = local.actual_gpu_count > 0 ? "nvidia" : null
        termination_grace_period_seconds = 60

        security_context {
          run_as_user     = 1000
          fs_group        = 1000
          run_as_non_root = true
        }

        # Image pull secret for private Docker Hub repository
        image_pull_secrets {
          name = var.docker_registry_secret
        }

        # Main workspace container
        container {
          name              = "coder-workspace-dev"
          image             = local.main_image
          image_pull_policy = "Always"
          command           = ["sh", "-c", coder_agent.main.init_script]

          # Environment variables
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }
          env {
            name  = "POD_MAIN_IMAGE_ID"
            value = local.main_image
          }
          env {
            name  = "HOME"
            value = "/home/coder"
          }
          env {
            name  = "LOGNAME"
            value = local.git_author_name
          }
          env {
            name  = "PATH"
            value = "/home/coder/.local/bin:/home/linuxbrew/.linuxbrew/opt/node@22/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/opt/venv-py312/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          }
          env {
            name  = "CODER_MCP_CLAUDE_API_KEY"
            value = data.coder_parameter.enable_advanced_tools.value && length(data.coder_parameter.anthropic_api_key) > 0 ? data.coder_parameter.anthropic_api_key[0].value : ""
          }
          env {
            name  = "CODER_MCP_CLAUDE_TASK_PROMPT"
            value = data.coder_parameter.ai_prompt.value
          }
          env {
            name  = "CODER_MCP_APP_STATUS_SLUG"
            value = "claude-code"
          }
          env {
            name  = "CODER_MCP_CLAUDE_SYSTEM_PROMPT"
            value = "You are a helpful assistant that can help with code."
          }
          env {
            name  = "GH_TOKEN"
            value = data.coder_parameter.enable_advanced_tools.value && length(data.coder_parameter.gh_token) > 0 ? data.coder_parameter.gh_token[0].value : ""
          }
          env {
            name  = "HF_TOKEN"
            value = data.coder_parameter.enable_advanced_tools.value && length(data.coder_parameter.hf_token) > 0 ? data.coder_parameter.hf_token[0].value : ""
          }
          env {
            name  = "DOCKER_PASSWORD"
            value = data.coder_parameter.enable_advanced_tools.value && length(data.coder_parameter.docker_password) > 0 ? data.coder_parameter.docker_password[0].value : ""
          }
          env {
            name  = "KUBECONFIG"
            value = "/home/coder/.kube/config"
          }
          env {
            name  = "_EXPERIMENTAL_DAGGER_RUNNER_HOST"
            value = data.coder_parameter.use_dagger.value ? "unix:///run/dagger/engine.sock" : ""
          }
          env {
            name  = "_EXPERIMENTAL_DAGGER_GPU_SUPPORT"
            value = "true"
          }
          env {
            name  = "DAGGER_CLOUD_TOKEN"  
            value = ""
          }
          env {
            name  = "DAGGER_NO_NAG"
            value = "1"
          }
          env {
            name  = "DAGGER_CLOUD_TOKEN"
            value = data.coder_parameter.enable_advanced_tools.value && length(data.coder_parameter.dagger_cloud_token) > 0 ? data.coder_parameter.dagger_cloud_token[0].value : ""
          }

          # Dynamic environment variables for external services
          dynamic "env" {
            for_each = local.internal_service_env_vars
            content {
              name  = env.key
              value = env.value
            }
          }

          # Resource allocation
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

          # Volume mounts
          volume_mount {
            mount_path = "/dev/shm"
            name       = "dshm"
            read_only  = false
          }

          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }

          volume_mount {
            mount_path = "/etc/secrets/lakefs"
            name       = "lakefs-secrets"
            read_only  = true
          }

          # Conditionally mount scratch volume (not in CI mode)
          dynamic "volume_mount" {
            for_each = local.is_ci ? [] : [1]
            content {
              mount_path = "/mnt/scratch"
              name       = "scratch"
              read_only  = false
            }
          }

          # Conditionally mount work volume (not in CI mode)
          dynamic "volume_mount" {
            for_each = local.is_ci ? [] : [1]
            content {
              mount_path = "/mnt/work"
              name       = "work"
              read_only  = false
            }
          }

          volume_mount {
            mount_path = "/home/coder/.kube"
            name       = "default-kubeconfig"
            read_only  = true
          }
          
          # Dagger engine communication (conditional)
          dynamic "volume_mount" {
            for_each = data.coder_parameter.use_dagger.value ? [1] : []
            content {
              mount_path = "/run/dagger"
              name       = "dagger-socket"
              read_only  = false
            }
          }
        }

        # Dagger Engine Sidecar (conditional)
        dynamic "container" {
          for_each = data.coder_parameter.use_dagger.value ? [1] : []
          content {
            name  = "dagger-engine"
            image = "registry.dagger.io/engine:v0.18.14-gpu"
            
            command = ["/usr/local/bin/dagger-engine"]
            args    = ["--config", "/etc/dagger/engine.toml"]

            env {
            name  = "_EXPERIMENTAL_DAGGER_GPU_SUPPORT"
            value = "true"
            }

            env {
              name  = "NVIDIA_VISIBLE_DEVICES"
              value = "all"
            }

            env {
            name  = "DO_NOT_TRACK"
            value = "1"
            }

            env {
              name  = "DAGGER_CLOUD_TOKEN"
              value = data.coder_parameter.enable_advanced_tools.value && length(data.coder_parameter.dagger_cloud_token) > 0 ? data.coder_parameter.dagger_cloud_token[0].value : ""
            }

            env {
              name  = "NVIDIA_DRIVER_CAPABILITIES"
              value = "compute,utility"
            }
            
            security_context {
              privileged                = true
              run_as_user              = 0
              run_as_group             = 1000
              run_as_non_root          = false
              allow_privilege_escalation = true
              capabilities {
                add = ["ALL"]
              }
            }
            
            readiness_probe {
              exec {
                command = ["dagger", "core", "version"]
              }
              initial_delay_seconds = 10
              period_seconds       = 10
              timeout_seconds      = 5
              failure_threshold    = 3
            }
            
            volume_mount {
              mount_path = "/run/dagger"
              name       = "dagger-socket"
            }
            
            volume_mount {
              mount_path = "/var/lib/dagger"
              name       = "dagger-storage"
            }

                    
            resources {
              requests = merge({
                "cpu"    = local.dagger_cpu_request
                "memory" = local.dagger_memory_request
              }) 
              limits = merge({
                "cpu"    = local.dagger_cpu_limit
                "memory" = "${local.dagger_memory_limit}Gi"
              }) 
            }
          }
        }

        # Volume definitions
        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
            read_only  = false
          }
        }


        volume {
          name = "lakefs-secrets"
          secret {
            secret_name = local.lakefs_secret_name
            items {
              key  = "access_key_id"
              path = "access_key_id"
            }
            items {
              key  = "secret_access_key"
              path = "secret_access_key"
            }
          }
        }

        # Conditionally define scratch volume (not in CI mode)
        dynamic "volume" {
          for_each = local.is_ci ? [] : [1]
          content {
            name = "scratch"
            host_path {
              path = "/mnt/scratch/"
              type = "Directory"
            }
          }
        }

        # Conditionally define work volume (not in CI mode)
        dynamic "volume" {
          for_each = local.is_ci ? [] : [1]
          content {
            name = "work"
            host_path {
              path = "/mnt/work/"
              type = "Directory"
            }
          }
        }

        volume {
          name = "dshm"
          empty_dir {
            medium     = "Memory"
            size_limit = "${floor(tonumber(data.coder_parameter.memory.value) * (data.coder_parameter.shared_memory_percentage.value / 100))}Gi"
          }
        }

        volume {
          name = "default-kubeconfig"
          secret {
            secret_name = "default-kubeconfig"
            items {
              key  = "config"
              path = "config"
              mode = "0400"
            }
          }
        }

        volume {
          name = "dagger-socket"
          empty_dir {}
        }

        volume {
          name = "dagger-storage"
          empty_dir {}
        }

        # Pod affinity rules
        affinity {
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
          
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/part-of"
                    operator = "In"
                    values   = ["coder"]
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
  resource_id = kubernetes_deployment.main[0].id
  icon        = "/emojis/1f9be.png"
  
  item {
    key   = "volume_claim"
    value = kubernetes_persistent_volume_claim.home.metadata[0].name
  }
  
  item {
    key   = "gpu_type"
    value = local.selected_gpu == "None" ? "No GPU" : local.selected_gpu
  }
  
  item {
    key   = "image_id"
    value = local.main_image
  }

  dynamic "item" {
    for_each = local.dagger_enabled ? [1] : []
    content {
      key   = "dagger"
      value = "Enabled (${local.dagger_cpu_limit} CPU, ${local.dagger_memory_limit}GB RAM)"
    }
  }
}


# ========================================
# Coder Resource Scripts
# ========================================


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

resource "coder_script" "lakefs_config" {
  agent_id           = coder_agent.main.id
  display_name       = "LakeFS Configuration"
  icon               = "/icon/lakefs.svg"
  log_path           = "lakefs_config.log"
  run_on_start       = true
  start_blocks_login = false
  
  script = replace(
    file("${path.module}/scripts/lakefs_config.sh"),
    "\r",
    ""
  )
}

resource "coder_script" "git_config" {
  agent_id           = coder_agent.main.id
  display_name       = "Git Configuration"
  icon               = "/icon/git.svg"
  log_path           = "git_config.log"
  run_on_start       = true
  start_blocks_login = false
  
  script = replace(
    templatefile("${path.module}/scripts/git_config.sh", {
      git_author_name  = local.git_author_name
      git_author_email = local.git_author_email
    }),
    "\r",
    ""
  )
}

resource "coder_script" "agents_config" {
  agent_id           = coder_agent.main.id
  display_name       = "Agents AI Setup"
  icon               = "/icon/claude.svg"
  log_path           = "agents_config.log"
  run_on_start       = true
  start_blocks_login = false
  
  script = replace(
    file("${path.module}/scripts/agents_config.sh"),
    "\r",
    ""
  )
}

resource "coder_script" "starship_config" {
  agent_id           = coder_agent.main.id
  display_name       = "Starship Prompt"
  icon               = "/icon/terminal.svg"
  log_path           = "starship_config.log"
  run_on_start       = true
  start_blocks_login = false
  
  script = replace(
    file("${path.module}/scripts/starship_config.sh"),
    "\r",
    ""
  )
}

resource "coder_script" "coder_cli_config" {
  agent_id           = coder_agent.main.id
  display_name       = "Coder CLI Setup"
  icon               = "/icon/coder.svg"
  log_path           = "coder_cli_config.log"
  run_on_start       = true
  start_blocks_login = false
  
  script = replace(
    templatefile("${path.module}/scripts/coder_cli_config.sh", {
      coder_url = "$${CODER_URL:-${var.temp_ip}}"
    }),
    "\r",
    ""
  )
}

resource "coder_script" "argo_token_setup" {
  agent_id           = coder_agent.main.id
  display_name       = "Argo Workflows Token Setup"
  icon               = "/icon/argo-workflows.svg"
  run_on_start       = true
  start_blocks_login = false
 
  script = <<-EOT
    #!/usr/bin/env bash
    
    if command -v argo &> /dev/null; then
      ARGO_TOKEN=$(argo auth token 2>/dev/null) || exit 0
      [ -n "$ARGO_TOKEN" ] && echo "export ARGO_TOKEN=\"$ARGO_TOKEN\"" >> "$HOME/.bashrc"
    fi
  EOT
}
