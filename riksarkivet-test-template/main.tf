terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Simple workspace template for testing
data "coder_workspace" "me" {}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
}

resource "kubernetes_pod" "workspace" {
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    namespace = "default"
  }
  
  spec {
    container {
      name    = "workspace"
      # This will be replaced with local registry during testing
      image   = "docker.io/riksarkivet/coder-workspace-ml:test"
      command = ["/bin/bash", "-c", "sleep infinity"]
      
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
    }
  }
}