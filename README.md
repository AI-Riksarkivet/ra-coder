# Coder Template: GPU-Accelerated Data Science & MLOps Environment

This Coder template provisions a comprehensive development environment tailored for GPU-accelerated data science, machine learning, and MLOps tasks. It leverages Docker for image creation and Terraform for deploying the workspace on Kubernetes.

The environment comes pre-configured with CUDA, Python, PyTorch, popular data science libraries, MLOps tools, an AI coding assistant (Aider), and the Continue extension for VS Code, all integrated with a local/network-accessible Large Language Model (LLM).

## Recent Updates

-  **SSH Auto-Configuration**: New containers automatically start SSH agent and load keys
-  **Modern Build System**: Simplified Dagger-based build for local directories only
-  **Local Build Support**: Build directly from current directory
-  **Streamlined Process**: No Git or authentication complexity
-  **Offline Development**: Working Dagger examples for restricted network environments
-  **Streamlined Structure**: Cleaned up documentation and improved project organization

## Features

* **Base OS:** Ubuntu 22.04 LTS (Jammy).
* **CUDA Enabled:** NVIDIA CUDA Toolkit 12.2 installed in the Docker image, supporting applications built with CUDA 12.1 (like PyTorch).
* **SSH Ready:** Automatic SSH agent configuration for seamless git operations with `devops.ra.se`
* **Python Environment:**
    * Python 3.12 installed via Homebrew.
    * Dedicated virtual environment (`/opt/venv-py312`) managed by `uv`.
    * Auto-activated venv and Homebrew shell environment upon terminal login.
* **ML Package Support:**
    * **PyTorch Ready:** CUDA 12.2 environment compatible with PyTorch CUDA 12.1 builds
    * **Fast Package Installation:** Use `uv` for quick ML package installation
    * **Framework Flexibility:** Install any ML framework (PyTorch, TensorFlow, JAX, etc.) as needed
* **Development Tools:**
    * `code-server` (VS Code in the browser) as the primary IDE.
    * Homebrew for package management.
    * Git, `pre-commit`, `ruff`, `huggingface-cli`, `duckdb`.
    * Kubernetes tools: `kubectl`, `helm`.
    * Modern build system with `dagger` module support.

## Quick Start

### Building Images with Dagger

```bash
# CPU build
dagger call build-local --source="./Riksarkivets-Development-Template" --enable-cuda=false

# GPU build
dagger call build-local --source="./Riksarkivets-Development-Template" --enable-cuda=true

# CUDA build with custom tag
dagger call build-local --source="./Riksarkivets-Development-Template" --enable-cuda=true --image-tag="v14.1.3"
```

### Offline Development

Test Dagger functionality without external registry access:

```bash
# Standalone offline example
go run offline-dagger-example.go

# Dagger module version
dagger call hello-world -m ./offline-example
dagger call simple-test -m ./offline-example
```

## Build System

This template uses a modern **Dagger-based build system** for local directory builds:

### Key Features
- **Local Builds**: Build directly from current directory
- **Simple Setup**: No Git or authentication required
- **Fast Builds**: Efficient Kaniko-based container builds
- **CPU/GPU Support**: Easy switching between CPU and CUDA builds
- **Offline Examples**: Test Dagger without external dependencies

### Dagger Functions

```bash
# CPU build
dagger call build-local --source="./Riksarkivets-Development-Template" --enable-cuda=false --image-tag="v14.1.3"

# CUDA build
dagger call build-local --source="./Riksarkivets-Development-Template" --enable-cuda=true --image-tag="v14.1.3"

# Build with different registry
dagger call build-local --source="./Riksarkivets-Development-Template" --enable-cuda=true --registry="custom.registry.com"
```

### Available Dagger Functions

- `build-local`: Build from specified local directory (use `./Riksarkivets-Development-Template` as source)
- `get-build-command`: Show example build commands
- `hello`: Display usage information

## SSH Configuration

New workspaces automatically include SSH configuration:

-  **SSH Agent**: Auto-starts and loads `~/.ssh/id_rsa` if present
-  **DevOps Integration**: Pre-configured for `devops.ra.se:22` Git access
-  **No Manual Setup**: Works immediately for Git operations

## Prerequisites

Before using this template, ensure you have:

1. **Coder Server:** A Coder v2 instance deployed and accessible.
2. **Kubernetes Cluster:** With appropriate GPU support if using GPUs.
3. **Container Registry:** Access to `registry.ra.se:5002` or configure custom registry.
4. **Build Tools:** Dagger CLI installed locally

## Workspace Parameters

Configure at workspace creation:
- **CPU/Memory:** 2-24 cores, 2-96GB RAM
- **GPU Support:** Optional NVIDIA RTX series GPUs
- **Storage:** Configurable home disk size
- **API Keys:** Anthropic, GitHub, Hugging Face tokens

## Development Environment

### Included Software
- **Languages:** Python 3.12, Go, Node.js 22
- **ML/AI:** PyTorch-ready, Hugging Face, MLflow
- **DevOps:** kubectl, helm, argo, terraform, dagger
- **Cloud:** AWS CLI, Azure CLI support
- **AI Assistants:** Aider, Continue extension, Claude Code

### Python Environment
```bash
# Pre-configured virtual environment with uv
uv add torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
uv add transformers datasets accelerate
uv add numpy pandas scikit-learn matplotlib
```

## Documentation

- **CLAUDE.md** - Complete project context and development guide
- **Riksarkivets-Development-Template/** - Core template files
- **offline-example/** - Offline Dagger examples for testing

## Version Information

**Current Versions:**
- **Template:** v14.1.3 (latest)
- **Container Images:** `registry.ra.se:5002/airiksarkivet/devenv:v14.1.3` (GPU), `v14.1.3-cpu` (CPU)
- **Build System:** Dagger module for local directory builds

## Support

For issues and contributions, see the repository documentation and examples provided in the `offline-example/` directory for testing Dagger functionality.