# CLAUDE.md - Project Context

## Project Overview
This is a **Coder Template** for provisioning GPU-accelerated data science and MLOps development environments. It creates Kubernetes-based workspaces with comprehensive tooling for machine learning, data science, and AI development.

## Technology Stack
- **Infrastructure**: Terraform (IaC), Kubernetes, Docker
- **Base Environment**: Ubuntu 22.04 LTS with NVIDIA CUDA 12.2
- **Development**: Python 3.12, PyTorch, VS Code (code-server)
- **MLOps**: MLflow, LakeFS, Argo Workflows
- **AI Tools**: Aider, Continue extension, vLLM integration

## Key Files & Structure
- `main.tf` - Main Terraform configuration for Kubernetes deployment
- `Dockerfile` - Container image definition with CUDA, Python, and dev tools
- `README.md` - Comprehensive documentation and setup instructions
- `build.sh` - Build script for Docker image
- `build.yaml` - Build configuration
- `Makefile` - Build automation

## Development Context
This template creates workspaces with:
- **Persistent storage**: Home directory backed by Kubernetes PVC
- **GPU support**: NVIDIA GPUs with proper runtime configuration
- **AI assistance**: Pre-configured Aider and Continue with local LLM
- **Pre-installed tools**: kubectl, helm, awscli, git, ruff, pre-commit
- **Python environment**: Virtual environment with PyTorch, transformers, pandas, scikit-learn

## Common Operations
- **Build image**: `make build` or `./build.sh`
- **Deploy template**: Import into Coder deployment
- **Workspace creation**: Configure CPU/memory/GPU via Coder parameters
- **Access**: Via code-server app in Coder dashboard

## Configuration Notes
- Requires `lakefs-secrets` Kubernetes secret for LakeFS integration
- Uses registry `registry.ra.se:5002/devenv:v8.0.0` for the container image
- LLM service expected at `http://llm-service.models:8000/v1`
- Supports GPU types: Quadro RTX 5000, NVIDIA RTX A5000/A6000, RTX 6000 Ada

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