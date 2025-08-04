# CLAUDE.md - Project Context

## Project Overview
This is a **Coder Template** for provisioning GPU-accelerated data science and MLOps development environments. It creates Kubernetes-based workspaces with comprehensive tooling for machine learning, data science, and AI development.

## Recent Improvements (v14.1.3+)
- ✅ **SSH Auto-Configuration**: Containers automatically configure SSH agent and load keys for seamless Git operations
- ✅ **Enhanced Dagger Module**: Improved Dagger functions with SSH authentication and local directory support
- ✅ **Local Build Support**: Build directly from current directory without Git requirements
- ✅ **SSH Key Compatibility**: Automatic SSH key format conversion for better compatibility
- ✅ **Flexible Build Sources**: Support for SSH, HTTPS, and local directory builds
- ✅ **Offline Development**: Added working Dagger examples that function without external registry access
- ✅ **Streamlined Structure**: Cleaned up documentation and removed obsolete files

## Technology Stack
- **Infrastructure**: Terraform (IaC), Kubernetes, Docker
- **Base Environment**: Ubuntu 22.04 LTS with NVIDIA CUDA 12.2
- **Development**: Python 3.12, PyTorch, VS Code (code-server)
- **MLOps**: MLflow, LakeFS, Argo Workflows
- **AI Tools**: Aider, Continue extension, vLLM integration

## Key Files & Structure
- `main.tf` - Main Terraform configuration for Kubernetes deployment
- `Dockerfile` - Container image definition with CUDA, Python, dev tools, and SSH auto-configuration
- `README.md` - Comprehensive documentation and setup instructions
- `.dagger/main.go` - Enhanced Dagger module with Git and local build support
- `build.yaml` - Argo build configuration (legacy)
- `offline-example/` - Offline Dagger examples for testing without external registries
- `offline-dagger-example.go` - Standalone offline Dagger example
- `go.mod` / `go.sum` - Go module dependencies for build system

## Development Context
This template creates workspaces with:
- **Persistent storage**: Home directory backed by Kubernetes PVC
- **GPU support**: NVIDIA GPUs with proper runtime configuration
- **SSH ready**: Auto-configured SSH agent and keys for seamless Git operations
- **AI assistance**: Pre-configured Aider and Continue with local LLM
- **Pre-installed tools**: kubectl, helm, awscli, git, ruff, pre-commit, dagger
- **Python environment**: Virtual environment with PyTorch, transformers, pandas, scikit-learn
- **Modern build system**: Go-based Dagger scripts for container builds

## Common Operations
- **Build from local**: `dagger call build-from-current-dir --enable-cuda=false` (CPU) or `--enable-cuda=true` (GPU)
- **Build from Git**: `dagger call build-cpu --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"`
- **Test offline**: `go run offline-dagger-example.go` or `dagger call simple-test -m ./offline-example`
- **Deploy template**: Import into Coder deployment
- **Workspace creation**: Configure CPU/memory/GPU via Coder parameters
- **Access**: Via code-server app in Coder dashboard

## Configuration Notes
- Requires `lakefs-secrets` Kubernetes secret for LakeFS integration
- Uses registry `registry.ra.se:5002/airiksarkivet/devenv:v14.1.3` (latest images)
- SSH auto-configuration for `ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates`
- LLM service expected at `http://llm-service.models:8000/v1`
- Supports GPU types: Quadro RTX 5000, NVIDIA RTX A5000/A6000, RTX 6000 Ada
- Go-based build system with offline development support

## Dependencies
- Kubernetes cluster with NVIDIA GPU support (if using GPUs)
- Coder v2 deployment
- Docker registry access
- LakeFS and MLflow services (optional)

## Security Considerations
- Runs as non-root user (UID 1000)
- Uses Kubernetes security contexts
- Secrets mounted from Kubernetes secret store
- No hardcoded credentials in configuration files