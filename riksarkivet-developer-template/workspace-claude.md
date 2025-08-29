# Riksarkivet AI-Powered Development Workspace

This document provides comprehensive information about this AI-enhanced development workspace to help Claude Code understand the environment, tools, capabilities, and best practices for effective assistance.

## 🏗️ Workspace Architecture

### Container Technology Stack
- **Base OS**: Ubuntu 22.04 LTS (Jammy)
- **Container Runtime**: Kubernetes-deployed workspace pods
- **Build System**: **Dagger** (containerized builds - preferred over Docker)

## 🛠️ Development Environment

### Programming Languages & Runtimes
- **Python**: 3.12 with virtual environment at `/opt/venv-py312`
- **Node.js**: v22 (via Homebrew) + npm with global Claude Code package
- **Go**: Latest version via Homebrew
- **Shell**: Bash with Starship prompt enhancement

### Package Managers
- **System Packages**: APT (Ubuntu package manager)
- **CLI Tools**: Homebrew (primary tool manager at `/home/linuxbrew/.linuxbrew`)
- **Python**: uv (modern Python package installer)
- **Node.js**: npm (comes with Node.js)

### Pre-installed Development Tools
```bash
# Build & Development
make, build-essential, pkg-config, gfortran, libopenblas-dev

# Version Control & CI/CD  
git, gh (GitHub CLI), argo, helm, kubectl, k9s

# Cloud & Infrastructure
awscli, azure-cli, terraform

# AI & ML Tools
huggingface-cli, duckdb, pre-commit, ruff

# Data & Analytics
lakefs (data versioning), duckdb (analytics database)

# System Utilities
htop, tree, unzip, wget, curl, jq, ripgrep, vim, nano, openssh

# Container & Build Tools
dagger (containerized builds), nvtop (GPU monitoring)
```

## 🚀 Containerized Build System (Dagger)

### Why Dagger Over Docker
**Important**: This workspace uses **Dagger** as the preferred containerized build system instead of Docker:

**Advantages of Dagger**:
- **Reproducible Builds**: Consistent across any environment
- **Portable Pipelines**: Write once, run anywhere (local, CI, cloud)
- **Better Caching**: Intelligent build caching and parallelization
- **API-First**: Programmable build pipelines in Go, Python, TypeScript
- **Security**: No Docker daemon required, reduced attack surface

**Dagger Configuration**:
- **Engine**: Available as optional sidecar container when enabled via workspace parameter
- **Socket**: Unix socket at `/run/dagger/engine.sock`
- **Resources**: Configurable CPU (2-24 cores) and memory (8-128GB)
- **GPU Support**: Experimental GPU acceleration enabled (`_EXPERIMENTAL_DAGGER_GPU_SUPPORT=true`)
- **Environment**: `_EXPERIMENTAL_DAGGER_RUNNER_HOST=unix:///run/dagger/engine.sock`


## 🤖 AI Assistant Integration

### Claude Code Setup
- **Installation**: Pre-installed via npm (`@anthropic-ai/claude-code`)
- **Configuration**: Reads this CLAUDE.md file for workspace context
- **API Integration**: Uses `CODER_MCP_CLAUDE_API_KEY` environment variable
- **Custom Prompts**: Configurable via `CODER_MCP_CLAUDE_TASK_PROMPT` workspace parameter
- **Status Integration**: `CODER_MCP_APP_STATUS_SLUG=claude-code`

## 💾 Storage Architecture

### Persistent Storage
- **Home Directory**: `/home/coder` (persistent across workspace restarts)
- **Size**: Configurable 5-1000GB via workspace parameter (default: 100GB)
- **Kubernetes**: PersistentVolumeClaim with ReadWriteOnce access mode

### Secret Management
- **LakeFS**: Access keys mounted from `lakefs-secrets` Kubernetes secret
- **Kubeconfig**: Default cluster access from `default-kubeconfig` secret
- **API Tokens**: Injected as environment variables from secure parameter storage
- **SSH Keys**: Optionally configured via workspace parameters for Git access

### GPU Resource Detection
**Check GPU Availability**:
```bash
# Verify GPU presence
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "GPU acceleration available"
    nvidia-smi
else
    echo "CPU-only environment"
fi

# Check GPU resources in Kubernetes
kubectl describe node $(kubectl get pods -o wide | grep $HOSTNAME | awk '{print $7}') | grep nvidia
```

### Runtime Security
- **User Context**: Runs as `coder` user (UID 1000, non-root)
- **File Permissions**: Proper ownership of home directory and mounted volumes
- **Sudo Access**: Passwordless sudo for system administration tasks

### Network & Service Access
- **Pod Networking**: Kubernetes native networking with service discovery
- **External Services**: 
  - MLflow Tracking Server: `MLFLOW_TRACKING_URI`
  - Argo Workflows: `ARGO_BASE_HREF`
- **Registry Authentication**: Supports private container registry access
- **SSH Management**: Secure private key handling for Git operations

### Environment Variables & Secrets
**Always Available**:
```bash
HOME=/home/coder
PATH=/home/coder/.local/bin:/home/linuxbrew/.linuxbrew/bin:...
KUBECONFIG=/home/coder/.kube/config
```


### Development Workflow Recommendations
1. **Version Control**: Git pre-configured with user info from Coder authentication
2. **Package Management**: Use `brew install` for CLI tools, `uv` for Python packages
3. **Container Builds**: Always prefer Dagger over Docker for builds
4. **AI Integration**: Leverage Claude Code context awareness and custom prompts
5. **Resource Awareness**: Consider workspace preset when suggesting operations

### File Organization Best Practices
- **User Projects**: `/home/coder/projects/` for personal development
- **Configuration**: Standard locations (`~/.config/`, `~/.local/`, etc.)
