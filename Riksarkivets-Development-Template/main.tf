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
  # Set a default namespace if you always expect the secret to be in 'coder'
  # default = "coder"
}

variable "mlflow_external_address" {
  type        = string
  description = "The external address for the MLflow Tracking Server UI (e.g., http://mlflow.example.com or http://<IP>:<Port>). Leave empty to disable the MLflow App and environment variable injection."
  default     = ""
}

variable "argowf_external_address" {
  type        = string
  description = "The external address for the Argo Workflow Server UI (e.g., http://argo.example.com or http://<IP>:<Port>). Leave empty to disable the Argo Workflow App and environment variable injection."
  default     = ""
}

variable "container_registry" {
  type        = string
  description = "The container registry URL for workspace images (e.g., registry.example.com:5000). Used for both base images and workspace container images."
  default     = "registry.ra.se:5002"
}

# variable "anthropic_api_key" {
#   type        = string
#   description = "The Anthropic API key"
#   sensitive   = true
# }

# Removed variables for LakeFS secrets as the secret is assumed to exist

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU"
  description  = "The number of CPU cores"
  default      = "2"
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
    name  = "6 Cores"
    value = "6"
  }
  option {
    name  = "8 Cores"
    value = "8"
  }
  option {
    name  = "12 Cores"
    value = "12"
  }
  option {
    name  = "16 Cores"
    value = "16"
  }
  option {
    name  = "20 Cores"
    value = "20"
  }
  option {
    name  = "24 Cores"
    value = "24"
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory"
  description  = "The amount of memory in GB"
  default      = "2"
  icon         = "/icon/memory.svg"
  mutable      = true

  option {
    name  = "2 GB"
    value = "2"
  }
  option {
    name  = "4 GB"
    value = "4"
  }
  option {
    name  = "6 GB"
    value = "6"
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
  default      = "10"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false

  validation {
    min = 1
    max = 99999
  }
}

data "coder_parameter" "gpu_type" {
  name         = "gpu_type"
  display_name = "GPU Type"
  description  = "Select the type of GPU required for the workspace."
  type         = "string"
  default      = "None"
  icon         = "/emojis/26a1.png"
  mutable      = false
  order        = 8

  # Added None option
  option {
    name  = "None"
    value = "None"
  }

  
   option {
    name  = "Quadro RTX 5000"
    value = "Quadro-RTX-5000"
  } 
  option {
    name  = "NVIDIA RTX A5000"
    value = "NVIDIA-RTX-A5000"
  }
  option {
    name  = "NVIDIA RTX A6000"
    value = "NVIDIA-RTX-A6000"
  }
  option {
    name  = "NVIDIA RTX 6000 Ada Generation"
    value = "NVIDIA-RTX-6000-Ada-Generation"
  }
}

data "coder_parameter" "gpu_count" {
  name         = "gpu_count"
  display_name = "Number of GPUs"
  description  = "Select the number of GPUs required (ignored if GPU Type is None)."
  type         = "number"
  default      = "0"
  icon         = "/emojis/0023-fe0f-20e3.png"
  mutable      = false
  order        = 9
  

  # Added 0 Gpu option
  option {
    name  = "0 Gpu(s)"
    value = "0"
  }
  option {
    name  = "1 Gpu"
    value = "1"
  }
  option {
    name  = "2 Gpu(s)"
    value = "2"
  }
  option {
    name  = "3 Gpu(s)"
    value = "3"
  }
  option {
    name  = "4 Gpu(s)"
    value = "4"
  }

}

data "coder_parameter" "ai_prompt" {
  type        = "string"
  name        = "ai_prompt"
  display_name = "AI Prompt"
  default     = ""
  description = "Write a prompt for Claude Code"
  mutable     = true
  order       = 10
}

data "coder_parameter" "anthropic_api_key" {
  type        = "string"
  name        = "anthropic_api_key"
  display_name = "Anthropic API Key"
  default     = ""
  description = "Your Anthropic API key for Claude Code web interface"
  mutable     = true
  order       = 11
}

data "coder_parameter" "gh_token" {
  type        = "string"
  name        = "gh_token"
  display_name = "GitHub Token"
  default     = ""
  description = "GitHub personal access token for API access"
  mutable     = true
  order       = 12
}

data "coder_parameter" "hf_token" {
  type        = "string"
  name        = "hf_token"
  display_name = "Hugging Face Token"
  default     = ""
  description = "Hugging Face access token for CLI and API access"
  mutable     = true
  order       = 13
}

provider "kubernetes" {
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# --- Coder Agent Configuration ---
resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"

  startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail # Use strict mode

    # --- Create Continue Config Directory ---
    echo "Setting up Continue Local Assistant configuration..."
    mkdir -p /home/coder/.continue

    # Create Continue config file
    cat > /home/coder/.continue/config.yaml <<'CONTINUECONFIG'
    name: Local Assistant
    version: 1.0.0
    schema: v1
    models:
      # VLLM OpenHands Model
      - name: OpenHands Local (vLLM)
        provider: vllm
        model: all-hands/openhands-lm-32b-v0.1
        apiBase:  http://llm-service.models:8000/v1
        roles:
          - chat
    context:
      - provider: code
      - provider: docs
      - provider: diff
      - provider: terminal
      - provider: problems
      - provider: folder
      - provider: codebase
CONTINUECONFIG


    # Read LakeFS secrets from mounted files and create .lakectl.yaml
    echo "Configuring lakectl.yaml..."
    # The secret is mounted at /etc/secrets/lakefs
    LAKECTL_ACCESS_KEY_ID=$(cat /etc/secrets/lakefs/access_key_id)
    LAKECTL_SECRET_ACCESS_KEY=$(cat /etc/secrets/lakefs/secret_access_key)

    cat > ~/.lakectl.yaml <<LAKECTLCONFIG
    credentials:
        access_key_id: "$${LAKECTL_ACCESS_KEY_ID}"
        secret_access_key: "$${LAKECTL_SECRET_ACCESS_KEY}"
    experimental:
        local:
            posix_permissions:
                enabled: false
    local:
        skip_non_regular_files: false
    metastore:
        glue:
            catalog_id: ""
        hive:
            db_location_uri: file:/user/hive/warehouse/
            uri: ""

    network:
        http2:
            enabled: true
    server:
        endpoint_url: http://lakefs.lakefs:80/
        retries:
            enabled: true
            max_attempts: 4
            max_wait_interval: 30s
            min_wait_interval: 200ms
LAKECTLCONFIG
    echo "lakectl.yaml configured."


    cat > ~/.aider.conf.yml <<'AIDERCONFIG'
    # /home/coder/.aider.conf.yml

    openai-api-base: http://llm-service.models:8000/v1

    # Add 'openai/' prefix to tell litellm how to treat the model
    model: openai/all-hands/openhands-lm-32b-v0.1

    openai-api-key: nokey # Assuming no key is needed for this local model

    # Other global defaults...
AIDERCONFIG


    echo "Aider config created at /home/coder/.aider.conf.yml"

    # --- Configure Git ---
    echo "Configuring Git user..."
    echo "Git author name: '${local.git_author_name}'"
    echo "Git author email: '${local.git_author_email}'"
    
    # Use Terraform interpolation to get owner name/email from locals
    if git config --global user.name "${local.git_author_name}"; then
        echo "Successfully set git user.name to '${local.git_author_name}'"
    else
        echo "ERROR: Failed to set git user.name"
    fi
    
    if git config --global user.email "${local.git_author_email}"; then
        echo "Successfully set git user.email to '${local.git_author_email}'"
    else
        echo "ERROR: Failed to set git user.email"
    fi
    
    # Verify git configuration
    echo "Current git configuration:"
    git config --list | grep user || echo "WARNING: No git user config found"

    # --- Configure Coder CLI ---
    echo "Configuring Coder CLI..."
    # Create coder config directory with basic URL configuration
    mkdir -p /home/coder/.config/coderv2
    cat > /home/coder/.config/coderv2/config.yaml <<CODERCONFIG
url: "$${CODER_URL:-http://10.100.127.31:30256}"
CODERCONFIG
    
    # Set proper ownership
    chown -R coder:coder /home/coder/.config/coderv2

    # --- SSH Key Generation ---
    echo "Setting up SSH keys for Git authentication..."
    if [ ! -f /home/coder/.ssh/id_rsa ]; then
      mkdir -p /home/coder/.ssh
      chmod 700 /home/coder/.ssh
      ssh-keygen -t rsa -b 4096 -f /home/coder/.ssh/id_rsa -N "" -C "${data.coder_workspace.me.owner_email}" >/dev/null 2>&1
      chmod 600 /home/coder/.ssh/id_rsa
      chmod 644 /home/coder/.ssh/id_rsa.pub
      echo "SSH key generated successfully."
      echo ""
      echo "-----------------------------------------------------"
      echo "SSH PUBLIC KEY FOR GIT AUTHENTICATION:"
      echo "-----------------------------------------------------"
      cat /home/coder/.ssh/id_rsa.pub
      echo "-----------------------------------------------------"
      echo "Add this key to your Git provider (Azure DevOps, GitHub, etc.)"
      echo "-----------------------------------------------------"
      echo ""
    else
      echo "SSH key already exists at /home/coder/.ssh/id_rsa"
    fi

    # --- Display External Service Info ---
    echo ""
    echo "-----------------------------------------------------"
    echo "External Service Information:"

    # Use $VARNAME for shell variables inside the Terraform heredoc.
    if [ -n "$MLFLOW_TRACKING_URI" ]; then
      echo "MLflow Tracking URI: $MLFLOW_TRACKING_URI"
    fi
    if [ -n "$ARGO_BASE_HREF" ]; then
      echo "Argo Workflow UI: $ARGO_BASE_HREF"
    fi
    echo "Coder agent setup complete. Workspace is starting."
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

  display_apps {
    vscode = false
    vscode_insiders = false
    ssh_helper = false
    port_forwarding_helper = false
    web_terminal = true
  }

}

# --- Locals ---
locals {

  git_author_name        = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  git_author_email       = data.coder_workspace_owner.me.email

  # --- GPU Logic ---
  selected_gpu           = data.coder_parameter.gpu_type.value
  selected_gpu_count_param = data.coder_parameter.gpu_count.value
  # The logic here correctly handles the "None" GPU case
  actual_gpu_count       = (local.selected_gpu == "None" || local.selected_gpu == "") ? 0 : tonumber(local.selected_gpu_count_param)
  gpu_resources          = local.actual_gpu_count > 0 ? { "nvidia.com/gpu" = format("%d", local.actual_gpu_count) } : {}
  gpu_label_key          = "nvidia.com/gpu.product"

  # --- External Service Environment Variables ---
  internal_service_env_vars = merge(
    var.mlflow_external_address != "" ? { "MLFLOW_TRACKING_URI" = var.mlflow_external_address } : {},
    var.argowf_external_address != "" ? { "ARGO_BASE_HREF" = var.argowf_external_address } : {},
    # Add other services back here if needed
  )

  # Define the LakeFS secret name based on the Coder username
  #lakefs_secret_name = "lakefs-secrets-${data.coder_workspace_owner.me.name}"
  lakefs_secret_name = "lakefs-secrets"

}

# --- Coder Apps ---
module "vscode-web" {
  count         = data.coder_workspace.me.start_count
  source        = "registry.coder.com/modules/vscode-web/coder"
  version       = "1.3.1"
  agent_id      = coder_agent.main.id
  accept_license = true
  subdomain     = false
  extensions    =  [ "ms-python.python", "ms-python.debugpy", "anthropic.claude-code"]
  telemetry_level = "off"
}

module "filebrowser" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/modules/filebrowser/coder"
  version   = "1.0.30"
  agent_id  = coder_agent.main.id
  subdomain = false
  database_path = ".config/filebrowser.db"
}


module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/dotfiles/coder"
  version  = "1.0.29"
  agent_id = coder_agent.main.id
}

module "claude-code" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/modules/claude-code/coder"
  version             = "2.0.3"
  agent_id            = coder_agent.main.id
  folder              = "/home/coder"
  install_claude_code = true
  claude_code_version = "1.0.62"

  # Enable experimental features
  experiment_report_tasks = false
}

# --- Kubernetes Persistent Volume Claim ---
resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "coder-pvc"
      "app.kubernetes.io/instance"   = "coder-pvc-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"    = "coder"
      # Coder-specific labels. (Corrected comment)
      "com.coder.resource"           = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
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
    # storage_class_name = "your-storage-class-name" # Specify if needed
  }
}

# --- Kubernetes Deployment for the Workspace Pod ---
resource "kubernetes_deployment" "main" {
  count        = data.coder_workspace.me.start_count
  # Removed dependency on the kubernetes_secret resource (as it's not created here)
  depends_on = [kubernetes_persistent_volume_claim.home]
  # wait_for_rollout = false # Optional

  metadata {
    name      = "coder-${data.coder_workspace.me.id}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "coder-workspace"
      "app.kubernetes.io/instance"   = "coder-workspace-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"    = "coder"
      "com.coder.resource"           = "true"
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
          "com.coder.workspace.id"     = data.coder_workspace.me.id
          "com.coder.workspace.name"   = data.coder_workspace.me.name
          "com.coder.user.id"          = data.coder_workspace_owner.me.id
          "com.coder.user.username"    = data.coder_workspace_owner.me.name
        }
      }
      spec {
        # runtime_class_name is set to null if no GPU is selected
        runtime_class_name = local.actual_gpu_count > 0 ? "nvidia" : null
        # --- IMPORTANT: Regarding Permissions ---
        # If NOT using a custom image with socat/curl pre-installed,
        # you MUST comment out/remove runAsNonRoot for the startup script's apt-get to work.
        # If using a custom image, keep runAsNonRoot: true for better security.
        security_context {
          run_as_user     = 1000
          fs_group        = 1000
          run_as_non_root = true # Assumes custom image OR modified permissions
        }
        termination_grace_period_seconds = 60

        container {
          name            = "coder-workspace-dev" # Renamed from "dev"
          image           = local.actual_gpu_count > 0 ? "${var.container_registry}/airiksarkivet/devenv:v14.0.0" : "${var.container_registry}/airiksarkivet/devenv:v14.0.0-cpu"
          image_pull_policy = "Always"
          command         = ["sh", "-c", coder_agent.main.init_script]

          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
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
            value = data.coder_parameter.anthropic_api_key.value
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
            value = <<-EOT
              You are a helpful assistant that can help with code.
            EOT
          }
          env {
            name  = "GH_TOKEN"
            value = data.coder_parameter.gh_token.value
          }
          env {
            name  = "HF_TOKEN"
            value = data.coder_parameter.hf_token.value
          }

          # Set KUBECONFIG environment variable
          env {
            name  = "KUBECONFIG"
            value = "/home/coder/.kube/config"
          }
          env {
            name  = "_EXPERIMENTAL_DAGGER_RUNNER_HOST"
            value = "tcp://dagger-dagger-helm-engine.dagger.svc.cluster.local:2345"
          }
          env {
            name  = "_EXPERIMENTAL_DAGGER_CLOUD_TOKEN"
            value = ""
          }
          env {
            name  = "DAGGER_CLOUD_TOKEN"  
            value = ""
          }
          env {
            name  = "_EXPERIMENTAL_DAGGER_CLOUD_ENABLED"
            value = "false"
          }
          env {
            name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
            value = ""
          }

          dynamic "env" {
            for_each = local.internal_service_env_vars
            content {
              name  = env.key
              value = env.value
            }
          }

          resources {
            requests = merge({
              "cpu"    = "250m"
              "memory" = "512Mi"
            }, local.gpu_resources) # gpu_resources is {} if no GPU
            limits = merge({
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }, local.gpu_resources) # gpu_resources is {} if no GPU
          }

          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }

          # Mount the LakeFS secrets - referencing the existing secret
          volume_mount {
            mount_path = "/etc/secrets/lakefs" # Choose a suitable mount path
            name       = "lakefs-secrets"
            read_only  = true
          }

          volume_mount {
            mount_path = "/mnt/scratch" # Mount path inside the container
            name       = "scratch"      # Must match the volume name below
            read_only  = false          # Allow writing to the scratch space
          }

          volume_mount {
            mount_path = "/mnt/work"    # Mount path inside the container
            name       = "work"         # Must match the volume name below
            read_only  = false          # Allow writing to the work space
          }

          # Mount default kubeconfig for basic cluster access
          volume_mount {
            mount_path = "/home/coder/.kube"
            name       = "default-kubeconfig"
            read_only  = true
          }
          # --- End ADDED Volume Mounts ---
        } # End container spec

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
            read_only  = false
          }
        }

        # Define the volume for LakeFS secrets - referencing the existing secret
        volume {
          name = "lakefs-secrets"
          secret {
            # Reference the pre-existing secret name and namespace
            # *** MODIFIED: Use local.lakefs_secret_name based on Coder username ***
            secret_name = local.lakefs_secret_name
            # The namespace is inherited from the Deployment's metadata.namespace
            items {
              key  = "access_key_id"
              path = "access_key_id" # The file will be created at /etc/secrets/lakefs/access_key_id
            }
            items {
              key  = "secret_access_key"
              path = "secret_access_key" # The file will be created at /etc/secrets/lakefs/secret_access_key
            }
          }
        }

        volume {
          name = "scratch"
          host_path {
            path = "/mnt/scratch/" # Path on the Kubernetes Node
            type = "Directory"     # Ensure it's a directory on the host
          }
        }

       
        volume {
          name = "work"
          host_path {
            path = "/mnt/work/"    # Path on the Kubernetes Node
            type = "Directory"     # Ensure it's a directory on the host
          }
        }


        # Mount default kubeconfig with limited permissions
        volume {
          name = "default-kubeconfig"
          secret {
            secret_name = "default-kubeconfig"  # This secret should contain a kubeconfig with limited RBAC
            items {
              key  = "config"
              path = "config"
              mode = "0400"  # Read-only for owner only
            }
          }
        }

        affinity {
          dynamic "node_affinity" {
            # Only apply node affinity if a GPU type other than "None" is selected
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
        } # End affinity
      }   # End pod spec
    }     # End template
  }       # End deployment spec
}         # End deployment resource