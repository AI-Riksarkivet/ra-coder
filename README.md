# Coder Templates Repository

> **⚠️ Work in Progress (WIP)**
> This repository is currently under active development. Templates, documentation, and build processes are being refined. Expect frequent changes and potential breaking updates. Use in production environments at your own discretion.

This repository contains Coder workspace templates for various development environments. Each template provides a complete, pre-configured development environment that can be deployed on Kubernetes through the Coder platform.

## 🚀 Build Pipeline (Dagger)

This repository uses [Dagger](https://dagger.io/) for building Docker images with a modern, programmable CI/CD pipeline written in Go.

### Prerequisites

1. **Dagger CLI**: Install Dagger on your local machine
   ```bash
   # macOS
   brew install dagger/tap/dagger
   
   # Linux
   curl -L https://dl.dagger.io/dagger/install.sh | sh
   
   # Windows (PowerShell)
   iwr https://dl.dagger.io/dagger/install.ps1 -useb | iex
   ```

2. **Docker**: Ensure Docker is running for local builds

3. **Registry Access**: For publishing images, ensure you have access to your target registry

4. **Environment Variables**: Set required credentials
   ```bash
   export DOCKER_PASSWORD="your-docker-hub-password-or-token"
   export CODER_TOKEN="your-coder-api-token"
   ```

### Primary Build Command

The main build command builds Docker images, pushes to Docker Hub, and uploads templates to your Coder instance:

```bash
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
  --template-name="Riksarkivets-Developer-Template" \
  --template-params "dotfiles_uri=https://github.com/AI-Riksarkivet/dotfiles" \
  --template-params "AI Prompt=" \
  --env-vars="ENABLE_CUDA=false"
```

This command will:
1. Build the Docker image with the specified parameters
2. Push the image to Docker Hub
3. Upload the template to your Coder instance with the new image reference

### Build Parameters

**Required Parameters:**
- `--cluster-name`: K3s cluster name for local testing
- `--source`: Local directory containing the template (e.g., `./riksarkivet-developer-template`)
- `--docker-username`: Docker Hub username for image pushing
- `--docker-password`: Docker Hub password/token (use `env:DOCKER_PASSWORD`)
- `--image-repository`: Repository name (e.g., `riksarkivet/workspace-developer`)
- `--image-tag`: Version tag for the image (e.g., `v1.0.0`)
- `--template-name`: Display name in Coder (max 32 characters)

**Coder Integration (Optional):**
- `--coder-url`: Coder server URL (use internal DNS when running in cluster)
- `--coder-token`: Coder API token (use `env:CODER_TOKEN`)

**Customization:**
- `--preset`: Coder preset to use for testing (e.g., `"Small Development"`)
- `--template-params`: Template parameters in `KEY=VALUE` format (can be repeated)
- `--env-vars`: Build environment variables in `KEY=VALUE` format (can be repeated)

### Getting Your Coder Token

```bash
# Login to your Coder instance
coder login http://your-coder-url

# Create a token with 1 year lifetime
coder tokens create --lifetime 168h --name "build-pipeline"

# Set as environment variable
export CODER_TOKEN="your-token-here"
```

### Environment Variables

Configure builds using these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `ENABLE_CUDA` | Enable GPU/CUDA support (`true`/`false`) | `false` |
| `PYTHON_VERSION` | Python version to install | `3.12` |

**Note**: When `ENABLE_CUDA=false`, the function automatically appends `-cpu` to the image tag.

## 📋 Available Templates

### Riksarkivet Developer Template
**Location**: `riksarkivet-developer-template/`

A comprehensive development environment optimized for the "Small Development" preset:

- **Base**: Ubuntu 22.04 with conditional CUDA support
- **Resources**: Optimized for 2 CPU, 4GB RAM, 10GB storage
- **Volume Mounts**: Conditionally mounts scratch and work volumes (skipped for small-dev preset)
- **AI Integration**: Claude Code and development tools
- **Modern Shell**: Starship prompt with Git integration

**Best for**: General development, CI/CD, lightweight development workflows

## 🎯 Quick Start

1. **Set Environment Variables**:
   ```bash
   export DOCKER_PASSWORD="your-docker-hub-token"
   export CODER_TOKEN="your-coder-api-token"
   ```

2. **Build and Deploy**:
   ```bash
   dagger call build-pipeline \
     --cluster-name="developer" \
     --source=./riksarkivet-developer-template \
     --docker-password=env:DOCKER_PASSWORD \
     --docker-username=your-username \
     --image-repository=your-org/workspace-developer \
     --image-tag=v1.0.0 \
     --coder-url=http://your-coder-server \
     --coder-token=env:CODER_TOKEN \
     --template-name="Your Template Name" \
     --env-vars="ENABLE_CUDA=false"
   ```

3. **Access Template**: The template will be automatically uploaded to your Coder instance and ready for workspace creation.

## 🔄 Automated Builds with Argo Workflows

This repository integrates with [Argo Workflows](https://argoproj.github.io/workflows/) to provide automated CI/CD pipeline capabilities for building and deploying Coder templates. Argo Workflows is a container-native workflow engine for orchestrating parallel jobs on Kubernetes.

### What is Argo Workflows?

[Argo Workflows](https://github.com/argoproj/argo-workflows) is an open-source, cloud-native workflow engine for Kubernetes that enables:
- **Container-native workflows**: Each step runs in its own container
- **Complex dependencies**: DAG-based workflow orchestration
- **Scalable execution**: Native Kubernetes resource management
- **Rich UI**: Web-based workflow visualization and monitoring

### Workflow Structure

The repository contains Argo Workflow configurations in multiple locations:

#### 1. Global Workflows (`argo-workflows/`)
- **`workflow-template.yaml`**: Reusable WorkflowTemplate for manual builds
- **`secrets-example.yaml`**: Example secret configurations for authentication

#### 2. Template-Specific Workflows
Each template directory contains its own Argo configurations:
- **`riksarkivet-developer-template/argo-workflows/`**:
  - `cron-workflow-cpu.yaml`: Nightly CPU-only builds (2 AM UTC)
  - `cron-workflow-gpu.yaml`: Nightly GPU-enabled builds (2 AM UTC)
- **`riksarkivet-agent-template/argo-workflows/`**:
  - `cron-workflow-cpu.yaml`: Agent template CPU builds
  - `cron-workflow-gpu.yaml`: Agent template GPU builds

### Workflow Features

**Automated Scheduling**: CronWorkflows run nightly builds with timestamped tags:
```yaml
schedule: "0 2 * * *"  # 2 AM UTC daily
image-tag: "nightly-{{workflow.creationTimestamp.Y}}-{{workflow.creationTimestamp.m}}-{{workflow.creationTimestamp.d}}"
```

**Dagger Integration**: Uses Dagger engine sidecar for containerized builds:
- Privileged execution for Docker-in-Docker
- Persistent volume claims for build caching
- GPU support for CUDA-enabled builds

**Multi-Environment Support**:
- Separate CPU and GPU build variants
- Configurable presets and parameters
- Environment-specific image tagging

### Prerequisites for Argo Workflows

1. **Argo Workflows Installation**: Deploy Argo Workflows on your Kubernetes cluster
   ```bash
   kubectl create namespace argo
   kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.4/install.yaml
   ```

2. **Required Secrets**: Configure the following Kubernetes secrets in your `ci` namespace:
   - `docker-registry-credentials`: Docker Hub authentication
   - `coder-credentials`: Coder server access credentials
   - `github-credentials`: GitHub access token for repository access
   - `dagger-cloud-token`: (Optional) Dagger Cloud integration

3. **Service Account**: Ensure proper RBAC permissions for the `ci-service-account`

4. **Namespace**: Workflows run in the `ci` namespace by default

### Manual Workflow Execution

Trigger manual builds using the Argo CLI or UI:

```bash
# Using Argo CLI
argo submit argo-workflows/workflow-template.yaml \
  --parameter image-tag=manual-v1.0.1 \
  --parameter template-name="Manual-Build" \
  -n ci

# Using kubectl
kubectl create -f argo-workflows/workflow-template.yaml -n ci
```

### Monitoring and Debugging

**Argo UI**: Access the workflow dashboard at `https://your-argo-server/workflows`

**Workflow Status**: Monitor workflow execution:
```bash
argo list -n ci
argo get <workflow-name> -n ci
argo logs <workflow-name> -n ci
```

**Common Issues**:
- **Secret Access**: Verify all required secrets exist in the `ci` namespace
- **Storage**: Ensure sufficient PVC storage for Dagger builds (10Gi default)
- **Permissions**: Check service account has necessary RBAC permissions
- **Resource Limits**: Monitor CPU/memory usage during parallel builds

## 📚 Additional Resources

- **[Coder Documentation](https://coder.com/docs)**: Official Coder platform documentation
- **[Dagger Documentation](https://docs.dagger.io/)**: Dagger build system documentation
- **[Argo Workflows Documentation](https://argo-workflows.readthedocs.io/)**: Complete Argo Workflows guide
- **[Argo Workflows GitHub](https://github.com/argoproj/argo-workflows)**: Official Argo Workflows repository
- **Template-Specific Docs**: See individual template directories for detailed documentation

## 🤝 Contributing

1. **Fork Repository**: Create your own fork for changes
2. **Follow Conventions**: Maintain the established directory and documentation structure
3. **Test Changes**: Verify builds and deployments work correctly
4. **Update Documentation**: Ensure all changes are documented
5. **Submit PR**: Create pull request with clear description

## 🆘 Support

For issues and questions:
- **Build Issues**: Review Dagger logs and configuration
- **Coder Integration**: Check your Coder server connectivity and token
- **Repository Issues**: Create GitHub issues with detailed descriptions