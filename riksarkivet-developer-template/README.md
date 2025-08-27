# Riksarkivet Starship Template

A modern, lightweight Coder template featuring a beautiful Starship prompt and optimized development environment. This template provides a streamlined workspace with modern CLI tools and excellent performance characteristics.

## Overview

This template creates a comprehensive development environment with:

- **Modern Shell Experience**: Starship prompt with Git integration and beautiful customization
- **Performance Optimized**: Fast startup times and low resource usage
- **Development Ready**: Essential tools and utilities for general development work
- **Flexible Configuration**: Easy customization through workspace parameters

## Features

### Development Environment
- **Base OS**: Ubuntu-based container with modern tooling
- **Shell**: Starship prompt with Git status, branch info, and customizable themes
- **Python**: Modern Python environment with package management
- **Development Tools**: Git, essential CLI utilities, and development libraries

### Modern CLI Tools
- **Package Management**: Homebrew for easy tool installation
- **Shell Enhancement**: Starship prompt with rich Git integration
- **Development Utilities**: Modern alternatives to traditional CLI tools
- **Build Tools**: Support for various development workflows

### IDE & Extensions
- **VS Code Web**: Browser-based development environment
- **Code Server**: Full VS Code experience accessible via web
- **Extensions**: Pre-configured with essential development extensions
- **File Browser**: Web-based file management interface

## Prerequisites

Before using this template, ensure you have:

1. **Coder Server**: A Coder v2 instance deployed and accessible
2. **Kubernetes Cluster**: 
   - Accessible by the Coder deployment
   - Sufficient resources for workspace containers
3. **Container Registry**: Access to the specified container image
4. **Kubernetes Namespace**: The target namespace must exist (default: `coder`)

## Workspace Parameters

Configure your workspace at creation time:

### Resource Allocation
- **CPU Cores**: 2-36 cores (default: 4)
- **Memory**: 8-180 GB RAM (default: 16 GB)
- **Home Disk**: 50-1000 GB persistent storage (default: 100 GB, immutable)
- **Shared Memory**: 0-80% of RAM for `/dev/shm` (default: 20%)

### GPU Configuration
- **GPU Type**: None, Quadro RTX 5000, NVIDIA RTX A5000, NVIDIA RTX 6000 Ada Generation
- **GPU Count**: 1-2 GPUs (for Ada Generation only)
- **Note**: GPU selection affects image variant (CPU vs GPU-enabled)

### Development Features
- **Dagger Engine**: Enable containerized build system (optional)
- **Advanced Tools**: Enable API tokens and SSH configuration
- **AI Integration**: Custom prompts for Claude Code assistant

### API Integration (Optional)
When "Advanced Tools" is enabled:
- **Anthropic API Key**: For Claude Code integration
- **GitHub Token**: Repository access and CLI authentication
- **Hugging Face Token**: Model downloads and Hub access
- **Docker Registry**: Password for private registry access
- **SSH Private Key**: Git repository access via SSH

## Template Variables

Configure these at the template level:

| Variable | Description | Default |
|----------|-------------|---------|
| `use_kubeconfig` | Use host kubeconfig vs in-cluster auth | `false` |
| `namespace` | Kubernetes namespace for workspaces | `"coder"` |
| `main_image_name` | Base container image name | `"riksarkivet/coder-workspace-ml"` |
| `main_image_tag` | Container image version | `"v14.3.0"` |
| `container_registry` | Registry URL for images | `"docker.io"` |
| `mlflow_external_address` | MLflow UI URL (optional) | `""` |
| `argowf_external_address` | Argo Workflows UI URL (optional) | `""` |

## Getting Started

### 1. Deploy Template
1. Import this template into your Coder deployment
2. Configure template variables for your environment
3. Ensure the container image is available in your registry

### 2. Build Container Image
Use the Dagger build system from the repository root:

```bash
# Build and publish GPU-enabled image
dagger call build-and-publish \
  --source="./riksarkivet-starship" \
  --username="your-username" \
  --password=env:DOCKER_PASSWORD \
  --env-vars="ENABLE_CUDA=true" \
  --image-tag="v14.3.0"

# Build and publish CPU-only image
dagger call build-and-publish \
  --source="./riksarkivet-starship" \
  --username="your-username" \
  --password=env:DOCKER_PASSWORD \
  --env-vars="ENABLE_CUDA=false" \
  --image-tag="v14.3.0"
```

### 3. Create Workspace
1. Navigate to Coder dashboard
2. Create new workspace using this template
3. Configure resource allocation and features
4. Launch workspace and connect via web IDE

### 4. Access Environment
- **VS Code Web**: Primary development interface
- **File Browser**: Web-based file management
- **Terminal**: Direct shell access with Starship prompt
- **Claude Code**: AI-powered coding assistant

## Workspace Presets

The template includes pre-configured workspace presets:

### Intense ML Training
- **Purpose**: High-performance ML/AI training
- **Resources**: 20 CPU, 96GB RAM, 500GB storage
- **Features**: Dual Ada GPUs, Dagger enabled
- **Use Case**: Large model training, intensive compute workloads

### Standard Data Science  
- **Purpose**: General data science work
- **Resources**: 8 CPU, 32GB RAM, 100GB storage
- **Features**: CPU-only, basic tooling
- **Use Case**: Data analysis, small-scale ML experiments

### Standard Development
- **Purpose**: General development with CI/CD
- **Resources**: 8 CPU, 32GB RAM, 100GB storage  
- **Features**: Dagger enabled, advanced tools
- **Use Case**: Software development, build automation

## Customization

### Modifying the Container
1. Update the `Dockerfile` in this directory
2. Rebuild using Dagger:
   ```bash
   dagger call build-and-publish \
     --source="./riksarkivet-starship" \
     --username="your-username" \
     --password=env:DOCKER_PASSWORD \
     --image-tag="custom-v1.0.0"
   ```
3. Update `main_image_tag` variable in template

### Adding Software
- **System Packages**: Modify Dockerfile to add `apt install` commands
- **CLI Tools**: Add Homebrew formulas to installation script
- **Python Packages**: Include in virtual environment setup
- **VS Code Extensions**: Add to extension installation script

### Environment Configuration
- **Shell Prompt**: Customize Starship configuration in startup scripts
- **Git Settings**: Automatically configured from Coder user information
- **Environment Variables**: Add through template parameters or startup scripts

## Monitoring & Resource Usage

The workspace includes comprehensive monitoring:

### Container Metrics
- CPU and memory usage (container and host)
- Home directory disk usage
- Load average and system performance

### GPU Monitoring (when enabled)
- GPU memory usage per device
- CUDA availability and status
- Driver capabilities

### Infrastructure Details
- Kubernetes node information
- Pod IP and networking details
- Resource allocation and limits

## Security Features

- **Non-root Execution**: Container runs as user `coder` (UID 1000)
- **Secret Management**: API tokens stored securely in Kubernetes secrets
- **Network Isolation**: Pod-level network policies
- **SSH Key Management**: Secure handling of private keys for Git access
- **Registry Authentication**: Support for private container registries

## Troubleshooting

### Common Issues

**Workspace won't start**:
- Check container image availability
- Verify namespace exists and has sufficient resources
- Review Kubernetes events for the deployment

**GPU not available**:
- Ensure GPU nodes are properly labeled
- Verify NVIDIA runtime is configured
- Check resource limits and requests

**Build failures**:
- Verify Dagger installation and configuration
- Check registry credentials and permissions
- Review build logs for specific errors

### Getting Help

- **Template Issues**: Check container logs and Kubernetes events
- **Resource Problems**: Monitor workspace metrics and node capacity
- **Build Issues**: Review Dagger logs and build output
- **Access Problems**: Verify network connectivity and authentication

## Version Information

**Current Versions**:
- **Container Image**: `v14.3.0`
- **Terraform Providers**: Coder >=2.4.0, Kubernetes latest
- **VS Code Modules**: Latest stable versions
- **Extensions**: Auto-updated from marketplace

## Related Documentation

- **Main Repository**: `../README.md` - Build system and template overview
- **Development Template**: `../riksarkivet-development-template/README.md` - Full ML/MLOps environment
- **Test Template**: `../riksarkivet-test-template/README.md` - Minimal testing environment