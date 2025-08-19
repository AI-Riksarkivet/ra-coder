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

# Variables for container image configuration
variable "image_registry" {
  description = "Container registry URL"
  type        = string
  default     = "docker.io"
}

variable "image_repository" {
  description = "Container image repository"
  type        = string
  default     = "riksarkivet/coder-workspace-ml"
}

variable "image_tag" {
  description = "Container image tag"
  type        = string
  default     = "latest"
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
      # Use the variables to construct the image URL
      image   = "${var.image_registry}/${var.image_repository}:${var.image_tag}"
      command = ["/bin/bash", "-c", "sleep infinity"]
      
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
    }
  }
}