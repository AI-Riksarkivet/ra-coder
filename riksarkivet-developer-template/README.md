# Riksarkivet Developer Template

A comprehensive, production-ready Coder template featuring GPU acceleration, AI-powered coding assistance, containerized build systems with Dagger, and intelligent resource management that adapts from lightweight CI/CD workflows to intensive ML training environments.

## Overview

This template creates a comprehensive development environment with:

- **Smart Resource Management**: Conditionally mounts volumes based on preset selection
- **Modern Shell Experience**: Starship prompt with Git integration
- **AI Integration**: Claude Code assistant with customizable prompts
- **Efficient Storage**: Skips scratch and work volumes for small development setups
- **Performance Optimized**: Fast startup times and low resource usage

## Features

### Conditional Volume Mounting
- **Small Development Preset**: Skips mounting `/mnt/scratch` and `/mnt/work` volumes
- **Other Presets**: Mounts full volume set for comprehensive development
- **Storage Optimization**: Reduces overhead for lightweight development workflows

### Development Environment
- **Base OS**: Ubuntu 22.04 with conditional CUDA support
- **Shell**: Starship prompt with Git status and customizable themes
- **Python**: Modern Python environment with package management
- **Development Tools**: Git, essential CLI utilities, and modern development libraries

### Modern CLI Tools
- **Package Management**: Homebrew for easy tool installation
- **Shell Enhancement**: Starship prompt with rich Git integration
- **AI Coding**: Claude Code integration with custom prompt support
- **Build Tools**: Support for various development workflows

### IDE & Extensions
- **VS Code Web**: Browser-based development environment
- **Code Server**: Full VS Code experience accessible via web
- **File Browser**: Web-based file management interface
- **Claude Code**: AI-powered coding assistant

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
- **CPU Cores**: 1-36 cores (default: 4)
- **Memory**: 3-180 GB RAM (default: 16 GB)
- **Home Disk**: 5-1000 GB persistent storage (default: 100 GB, immutable)
- **Shared Memory**: 0-80% of RAM for `/dev/shm` (default: 20%)

### GPU Configuration
- **GPU Type**: None, Quadro RTX 5000, NVIDIA RTX A5000, NVIDIA RTX 6000 Ada Generation
- **GPU Count**: 1-2 GPUs (for Ada Generation only)
- **Note**: GPU selection affects image variant (CPU vs GPU-enabled)

### Development Features
- **AI Prompt**: Custom prompt for Claude Code AI assistant
- **Dagger Engine**: Enable containerized build system (optional)
- **Advanced Tools**: Enable API tokens and SSH configuration

### API Integration (Optional)
When "Advanced Tools" is enabled:
- **Anthropic API Key**: For Claude Code integration
- **GitHub Token**: Repository access and CLI authentication
- **Hugging Face Token**: Model downloads and Hub access
- **Docker Registry**: Password for private registry access
- **SSH Private Key**: Git repository access via SSH

## Template Variables

These variables are automatically set by the Dagger build pipeline:

| Variable | Description | Example |
|----------|-------------|---------|
| `image_registry` | Container registry URL | `"docker.io"` |
| `image_repository` | Container image repository | `"riksarkivet/workspace-developer"` |
| `image_tag` | Container image tag | `"v1.0.0"` |
| `use_kubeconfig` | Use host kubeconfig vs in-cluster auth | `false` |
| `namespace` | Kubernetes namespace for workspaces | `"coder"` |

## Getting Started

### 1. Build and Deploy with Dagger

Use the main build pipeline to build the image and deploy the template:

```bash
# Set environment variables
export DOCKER_PASSWORD="your-docker-hub-password"
export CODER_TOKEN="your-coder-api-token"

# Build and deploy everything
dagger call build-pipeline \
  --cluster-name="developer" \
  --source=./riksarkivet-developer-template \
  --docker-password=env:DOCKER_PASSWORD \
  --docker-username=airiksarkivet \
  --image-repository=riksarkivet/workspace-developer \
  --image-tag=v1.0.0 \
  --preset "Small Development" \
  --coder-url=http://coder.coder.svc.cluster.local \
  --coder-token=env:CODER_TOKEN \
  --template-name="Riksarkivets-Developer-Template-CPU" \
  --template-params "dotfiles_uri=https://github.com/AI-Riksarkivet/dotfiles" \
  --template-params "AI Prompt=" \
  --env-vars="ENABLE_CUDA=false"

dagger call build-pipeline \
  --cluster-name="developer" \
  --source=./riksarkivet-developer-template \
  --docker-password=env:DOCKER_PASSWORD \
  --docker-username=airiksarkivet \
  --image-repository=riksarkivet/workspace-developer \
  --image-tag=v1.0.0 \
  --preset "Small Development" \
  --coder-url=http://coder.coder.svc.cluster.local \
  --coder-token=env:CODER_TOKEN \
  --template-name="Riksarkivets-Developer-Template-GPU" \
  --template-params "dotfiles_uri=https://github.com/AI-Riksarkivet/dotfiles" \
  --template-params "AI Prompt=" \
  --env-vars="ENABLE_CUDA=true"


```

This will:
1. Build the Docker image (CPU-optimized for ENABLE_CUDA=false)
2. Push to Docker Hub
3. Upload template to your Coder instance with correct image reference

### 2. Create Workspace
1. Navigate to Coder dashboard
2. Create new workspace using "Riksarkivets-Developer-Template"
3. Select "Small Development" preset for optimized resource usage
4. Launch workspace and connect via web IDE

### 3. Access Environment
- **VS Code Web**: Primary development interface
- **File Browser**: Web-based file management
- **Terminal**: Direct shell access with Starship prompt
- **Claude Code**: AI-powered coding assistant

## Workspace Presets

The template includes pre-configured workspace presets with smart volume mounting:

### Small Development (Optimized)
- **Purpose**: Lightweight development and CI/CD
- **Resources**: 2 CPU, 4GB RAM, 10GB storage
- **Features**: No scratch/work volumes, efficient storage
- **Use Case**: Small projects, testing, CI workflows

### Standard Data Science  
- **Purpose**: General data science work
- **Resources**: 8 CPU, 32GB RAM, 100GB storage
- **Features**: Full volume mounts, CPU-only
- **Use Case**: Data analysis, ML experiments

### Standard Development
- **Purpose**: General development with full toolset
- **Resources**: 8 CPU, 32GB RAM, 100GB storage  
- **Features**: Dagger enabled, full volume mounts
- **Use Case**: Software development, build automation

### Intense ML Training
- **Purpose**: High-performance ML/AI training
- **Resources**: 20 CPU, 96GB RAM, 500GB storage
- **Features**: Dual Ada GPUs, Dagger enabled, full volumes
- **Use Case**: Large model training, intensive compute workloads

## Volume Management

The template intelligently manages volume mounts based on your preset:

### Small Development Preset
- ✅ Home directory: `/home/coder` (persistent)
- ✅ Shared memory: `/dev/shm` (temporary)
- ✅ Kubeconfig: `/home/coder/.kube` (from secret)
- ❌ Scratch volume: `/mnt/scratch` (not mounted)
- ❌ Work volume: `/mnt/work` (not mounted)

### Other Presets
- ✅ All volumes from Small Development preset
- ✅ Scratch volume: `/mnt/scratch` (host path)
- ✅ Work volume: `/mnt/work` (host path)

## Customization

### Modifying the Container
1. Update the `Dockerfile` in this directory
2. Rebuild using Dagger:
   ```bash
   dagger call build-pipeline \
     --source=./riksarkivet-developer-template \
     --docker-password=env:DOCKER_PASSWORD \
     --docker-username=your-username \
     --image-repository=your-org/workspace-developer \
     --image-tag=custom-v1.0.0 \
     --coder-url=http://your-coder-server \
     --coder-token=env:CODER_TOKEN \
     --template-name="Your-Custom-Template"
   ```

### Adding Software
- **System Packages**: Modify Dockerfile to add `apt install` commands
- **CLI Tools**: Add Homebrew formulas to installation script
- **Python Packages**: Include in virtual environment setup
- **VS Code Extensions**: Add to extension installation script

### Environment Configuration
- **Shell Prompt**: Customize Starship configuration in startup scripts
- **Git Settings**: Automatically configured from Coder user information
- **AI Prompts**: Set custom prompts via workspace parameters

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

**Volume mount errors**:
- Ensure host paths exist for scratch/work volumes (non-small-dev presets)
- Check node labeling and storage availability

**Build failures**:
- Verify Dagger installation and Docker access
- Check registry credentials and permissions
- Review build logs for specific errors

### Getting Help

- **Template Issues**: Check container logs and Kubernetes events
- **Resource Problems**: Monitor workspace metrics and node capacity
- **Build Issues**: Review Dagger logs and build output
- **Volume Issues**: Check preset selection and host path availability

## Version Information

**Current Template**:
- **Image Variables**: Dynamic via Dagger build pipeline
- **Terraform Providers**: Coder >=2.4.0, Kubernetes latest
- **VS Code Modules**: Latest stable versions
- **Extensions**: Auto-updated from marketplace

## Related Documentation

- **Main Repository**: `../README.md` - Build system and primary build command
- **Argo Workflows**: `../argo-workflows/README.md` - Automated build setup
- **Build Pipeline**: Uses Dagger for image building and template deployment