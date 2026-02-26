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



variable "docker_registry_secret" {
  type        = string
  description = "The name of the Kubernetes secret containing Docker registry credentials for pulling private images."
  default     = "dockerhub-secret"
}

variable "image_repository" {
  type        = string
  description = "Container image repository name (e.g., riksarkivet/workspace-agent)"
  default     = "riksarkivet/workspace-agent"
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
  main_image = "${var.image_registry}/${var.image_repository}:${var.image_tag}"




  
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



# --- Agent Repository Configuration ---
data "coder_parameter" "agent_git_repo" {
  name         = "agent_git_repo"
  display_name = "Agent Repository URL"
  description  = "Git repository containing your agent code (e.g., https://github.com/org/agent-repo)"
  type         = "string"
  default      = ""
  mutable      = true
  form_type    = "input"
  order        = 10
  
  styling = jsonencode({
    placeholder = "https://github.com/your-org/your-agent-repo"
  })
}

data "coder_parameter" "agent_git_branch" {
  name         = "agent_git_branch"
  display_name = "Git Branch/Tag"
  description  = "Branch, tag, or commit to checkout (default: main)"
  type         = "string"
  default      = "main"
  mutable      = true
  form_type    = "input"
  order        = 11
  
  styling = jsonencode({
    placeholder = "main, v1.0.0, or commit hash"
  })
}

data "coder_parameter" "agent_work_dir" {
  name         = "agent_work_dir"
  display_name = "Agent Working Directory"
  description  = "Directory name for the cloned repository (default: agent)"
  type         = "string"
  default      = "agent"
  mutable      = false
  form_type    = "input"
  order        = 12
}

# --- Agent Execution Configuration ---
data "coder_parameter" "ai_prompt" {
  name         = "AI Prompt"
  display_name = "Agent Task Instructions"
  description  = "Complete instructions for the agent including what to run, analyze, and how to report results"
  type         = "string"
  default      = ""
  mutable      = true
  form_type    = "textarea"
  order        = 20
  
  styling = jsonencode({
    placeholder = "Example: Run python k8s_cluster_investigator_v2.py to check cluster state. Analyze the results and identify any issues. Then use slackme -c ml-team -m 'summary' to notify the team with your findings."
  })
}

data "coder_parameter" "agent_auto_run" {
  name         = "agent_auto_run"
  display_name = "Auto-execute Agent on Startup"
  description  = "Automatically execute the agent task when workspace starts"
  type         = "bool"
  default      = true
  form_type    = "checkbox"
  order        = 21
}




# --- API Keys & Tokens (conditional) ---

data "coder_parameter" "enable_advanced_tools" {
  name         = "enable_advanced_tools"
  display_name = "Enable Advanced Development Tools"
  description  = "Enable additional API tokens and SSH configuration"
  type         = "bool"
  default      = true
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
  version       = "1.1.4"
  agent_id      = coder_agent.main.id
  subdomain     = false
  database_path = ".config/filebrowser.db"
  folder        = "/"
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

module "slackme" {
  count            = data.coder_workspace.me.start_count
  source           = "git::https://github.com/AI-Riksarkivet/coder-modules.git//slackme?ref=main"
  agent_id         = coder_agent.main.id
  auth_provider_id = "slack"
  slack_message    = <<EOF
🤖 Agent task: $COMMAND took $DURATION to complete!
EOF
}


# Git Clone Script for Agent Repository (replaced module with custom script for GH_TOKEN support)
resource "coder_script" "git_clone_agent" {
  count              = data.coder_parameter.agent_git_repo.value != "" ? data.coder_workspace.me.start_count : 0
  agent_id           = coder_agent.main.id
  display_name       = "Git Clone"
  icon               = "/icon/git.svg"
  log_path           = "git_clone.log"
  run_on_start       = true
  start_blocks_login = false
  
  script = replace(
    file("${path.module}/scripts/git_clone_agent.sh"),
    "\r",
    ""
  )
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
        runtime_class_name                = null
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
            name  = "AGENT_AUTO_RUN"
            value = data.coder_parameter.agent_auto_run.value ? "true" : "false"
          }
          env {
            name  = "AGENT_GIT_REPO"
            value = data.coder_parameter.agent_git_repo.value
          }
          env {
            name  = "AGENT_GIT_BRANCH"
            value = data.coder_parameter.agent_git_branch.value
          }
          env {
            name  = "AGENT_WORK_DIR"
            value = data.coder_parameter.agent_work_dir.value
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
            name  = "KUBECONFIG"
            value = "/home/coder/.kube/config"
          }


          # Resource allocation
          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
            limits = {
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
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
            mount_path = "/home/coder/.kube"
            name       = "default-kubeconfig"
            read_only  = true
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


        # Pod affinity rules
        affinity {
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
    key   = "image_id"
    value = local.main_image
  }

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

resource "coder_script" "agent_runner" {
  agent_id           = coder_agent.main.id
  display_name       = "Agent Auto-Runner"
  icon               = "/icon/bolt.svg"
  log_path           = "agent_runner.log"
  run_on_start       = true
  start_blocks_login = false

  # Ensure git clone completes before running the agent
  depends_on = [
    coder_script.git_clone_agent
  ]

  script = replace(
    file("${path.module}/scripts/agent_runner.sh"),
    "\r",
    ""
  )
}

