# Riksarkivet Test Template

A minimal Coder template designed for testing, experimentation, and rapid prototyping. This template provides a lightweight environment that's perfect for validating configurations, testing new features, or running quick experiments.

## Overview

This template creates a basic development environment with:

- **Minimal Footprint**: Lightweight container with essential tools only
- **Fast Deployment**: Quick startup times for rapid testing cycles
- **Simple Configuration**: Minimal parameters and straightforward setup
- **Flexible Base**: Easy to customize and extend for specific testing needs

## Features

### Core Environment
- **Base Container**: Standard workspace image from the riksarkivet collection
- **Essential Tools**: Basic development utilities and CLI tools
- **Simple Setup**: Single container deployment with minimal dependencies
- **Quick Access**: Web-based IDE and terminal access

### Container Configuration
- **Image**: Uses the same base image as other templates (`riksarkivet/coder-workspace-ml`)
- **Runtime**: Standard container runtime (no GPU requirements)
- **Resources**: Configurable CPU, memory, and storage allocation
- **Networking**: Standard Kubernetes pod networking

### Development Interface
- **Command Execution**: Direct bash shell access
- **Coder Agent**: Standard Coder agent for workspace management
- **Token Authentication**: Secure connection via Coder agent token
- **Environment Variables**: Basic environment setup for development

## Prerequisites

Before using this template, ensure you have:

1. **Coder Server**: A Coder v2 instance (requires Coder provider ~> 0.12.0)
2. **Kubernetes Cluster**: 
   - Accessible by the Coder deployment
   - Basic resource availability for lightweight workspaces
3. **Container Image**: Access to the test container image
4. **Kubernetes Namespace**: Target namespace (default: `default`)

## Configuration

### Container Settings

The template uses a simple pod configuration:

```hcl
resource "kubernetes_pod" "workspace" {
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    namespace = "default"
  }
  
  spec {
    container {
      name    = "workspace"
      image   = "docker.io/riksarkivet/coder-workspace-ml:test"
      command = ["/bin/bash", "-c", "sleep infinity"]
      
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
    }
  }
}
```

### Resource Allocation

**Default Resources**:
- **CPU**: As allocated by Kubernetes scheduler
- **Memory**: As allocated by Kubernetes scheduler
- **Storage**: No persistent storage (ephemeral only)
- **Network**: Standard pod networking

**Note**: This template uses the default Kubernetes resource allocation. For production workloads, consider adding explicit resource requests and limits.

## Getting Started

### 1. Build Test Image

Use the Dagger build system from the repository root:

```bash
# Build test image (CPU-only is sufficient for testing)
dagger call build-and-publish \
  --source="./riksarkivet-test-template" \
  --username="your-username" \
  --password=env:DOCKER_PASSWORD \
  --env-vars="ENABLE_CUDA=false" \
  --image-tag="test"

# Or use a custom tag
dagger call build-and-publish \
  --source="./riksarkivet-test-template" \
  --username="your-username" \
  --password=env:DOCKER_PASSWORD \
  --env-vars="ENABLE_CUDA=false" \
  --image-tag="v1.0.0-test"
```

### 2. Deploy Template

1. Import this template into your Coder deployment
2. No template variables need to be configured (uses defaults)
3. Ensure the test image is available in your registry

### 3. Create Test Workspace

1. Navigate to Coder dashboard
2. Create new workspace using this template
3. Workspace will start with minimal configuration
4. Connect via Coder agent once ready

### 4. Access Environment

- **Terminal**: Direct bash shell access through Coder
- **Agent**: Standard Coder agent functionality
- **Basic Tools**: Whatever is included in the base image

## Use Cases

### Configuration Testing
- Test new Coder configurations
- Validate template changes
- Experiment with Kubernetes settings
- Debug deployment issues

### Development Experiments
- Quick environment for testing scripts
- Temporary workspace for experiments
- Isolated environment for risky operations
- Learning and training environments

### CI/CD Testing
- Test build processes in clean environment
- Validate container configurations
- Debug deployment pipelines
- Integration testing

### Registry Testing
- Test image builds and deployments
- Validate registry access and authentication
- Test different image variants
- Verify image functionality

## Customization

### Modifying the Container

1. **Update Image**: Change the `image` field in `main.tf`
2. **Add Environment Variables**: Extend the `env` block
3. **Change Command**: Modify the `command` and `args`
4. **Add Resources**: Include resource requests and limits

Example with resources:
```hcl
container {
  name    = "workspace"
  image   = "docker.io/riksarkivet/coder-workspace-ml:test"
  command = ["/bin/bash", "-c", "sleep infinity"]
  
  resources {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "1Gi"
    }
  }
  
  env {
    name  = "CODER_AGENT_TOKEN"
    value = coder_agent.main.token
  }
  
  env {
    name  = "TEST_ENV"
    value = "testing"
  }
}
```

### Adding Persistent Storage

```hcl
# Add to the container spec
volume_mount {
  mount_path = "/workspace"
  name       = "workspace-storage"
}

# Add to the pod spec
volume {
  name = "workspace-storage"
  empty_dir {
    size_limit = "1Gi"
  }
}
```

### Extending with More Features

To add more functionality, consider:

1. **Adding Parameters**: Create `coder_parameter` resources for user configuration
2. **Adding Apps**: Include VS Code, file browser, or other Coder apps
3. **Adding Scripts**: Include startup scripts for environment setup
4. **Adding Metadata**: Include resource metadata for monitoring

## Testing Workflows

### Image Testing
```bash
# Build test image
dagger call build-and-publish \
  --source="./riksarkivet-test-template" \
  --username="testuser" \
  --password=env:TEST_PASSWORD \
  --image-tag="experimental"

# Create workspace with new image
# Test functionality
# Validate results
```

### Template Validation
```bash
# Deploy template to test Coder instance
# Create multiple test workspaces
# Verify workspace creation and deletion
# Test agent connectivity
```

### Configuration Testing
```bash
# Test different Kubernetes configurations
# Validate resource allocation
# Test networking and storage
# Verify security contexts
```

## Limitations

### Current Limitations
- **No Persistent Storage**: Workspace data is ephemeral
- **No Resource Limits**: Uses default Kubernetes allocation
- **Minimal Tooling**: Only basic tools included in base image
- **No GPU Support**: CPU-only configuration
- **No Advanced Features**: No apps, extensions, or integrations

### Extending Beyond Testing

For production workloads, consider using:
- **Development Template**: Full-featured ML/MLOps environment
- **Starship Template**: Modern development environment with enhanced tooling
- **Custom Template**: Purpose-built for specific requirements

## Troubleshooting

### Common Issues

**Pod won't start**:
- Check image availability and accessibility
- Verify namespace exists and has permissions
- Review Kubernetes events for error details

**Agent connection fails**:
- Verify Coder agent token is properly set
- Check network connectivity between pod and Coder server
- Review agent logs for connection errors

**Build failures**:
- Verify Dagger configuration and connectivity
- Check registry credentials and permissions
- Review build logs for specific errors

### Debugging Commands

```bash
# Check pod status
kubectl get pods -n default

# View pod logs
kubectl logs <pod-name> -n default

# Describe pod for events
kubectl describe pod <pod-name> -n default

# Check Coder agent status
coder list
```

## Version Information

**Current Versions**:
- **Terraform Providers**: Coder ~> 0.12.0, Kubernetes ~> 2.23
- **Container Image**: `riksarkivet/coder-workspace-ml:test`
- **Kubernetes API**: Compatible with Kubernetes 1.20+

## Related Documentation

- **Main Repository**: `../README.md` - Build system and template overview
- **Development Template**: `../riksarkivet-development-template/README.md` - Full-featured environment
- **Starship Template**: `../riksarkivet-starship/README.md` - Modern development environment