# Coder Templates Repository

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

## 🔄 Automated Builds

For automated nightly builds, see the `argo-workflows/` directory which contains:
- WorkflowTemplate for manual triggers
- CronWorkflow for scheduled builds
- Complete setup documentation

## 📚 Additional Resources

- **[Coder Documentation](https://coder.com/docs)**: Official Coder platform documentation
- **[Dagger Documentation](https://docs.dagger.io/)**: Dagger build system documentation
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