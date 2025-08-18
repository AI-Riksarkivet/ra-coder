# CLAUDE.md - Riksarkivet Development Workspace Context

## Workspace Environment Overview
You are operating within a **GPU-accelerated data science and MLOps development environment** provided by **Riksarkivet (Swedish National Archives)**. This workspace is designed for machine learning, data science, AI development, and MLOps tasks.

## System Information
- **Base OS**: Ubuntu 22.04 LTS (Jammy)
- **User**: `coder` (UID 1000, GID 1000) with passwordless sudo access
- **Home Directory**: `/home/coder` (persistent via Kubernetes PVC)
- **CUDA Support**: NVIDIA CUDA Toolkit 12.2 (GPU workspaces)
- **Container Registry**: `docker.io/riksarkivet/coder-workspace-ml:v14.2.0`
- **Infrastructure**: Kubernetes-based deployment with Coder v2

## Python Environment
- **Python Version**: 3.12 (installed via Homebrew)
- **Virtual Environment**: `/opt/venv-py312` (auto-activated in shells)
- **Package Manager**: `uv` (fast Python package installer)
- **Environment Activation**: Automatic via `.bashrc` and `.profile`

### Python Package Installation
```bash
# Install packages using uv (recommended)
uv add torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121  # PyTorch with CUDA
uv add numpy pandas scikit-learn matplotlib seaborn  # Data science essentials
uv add transformers datasets accelerate  # Hugging Face ecosystem
uv add mlflow wandb  # MLOps tools
uv add aider-chat  # AI coding assistant
```

## Development Tools & CLI Applications

### Package Management
- **Homebrew**: `/home/linuxbrew/.linuxbrew` (primary package manager)
- **uv**: Fast Python package installer and resolver

### Kubernetes & Cloud Tools
- **kubectl**: Kubernetes CLI (configured with limited RBAC)
- **helm**: Kubernetes package manager  
- **k9s**: Kubernetes TUI
- **argo**: Argo Workflows CLI
- **awscli**: AWS CLI
- **azure-cli**: Azure CLI (if enabled)

### Development & ML Tools
- **git**: Version control (auto-configured with user details)
- **gh**: GitHub CLI (token configurable via workspace parameters)
- **ruff**: Python linter and formatter
- **pre-commit**: Git hooks management
- **huggingface-cli**: Hugging Face Hub CLI (token configurable)
- **lakefs**: Data versioning CLI (configured via secrets)
- **duckdb**: In-process analytical database
- **terraform**: Infrastructure as Code tool
- **dagger**: Container build system
- **ripgrep**: Fast text search tool

### System Utilities
- **htop**, **tree**, **unzip**, **wget**, **curl**, **jq**
- **vim**, **nano**: Text editors
- **nvtop**: NVIDIA GPU monitoring (GPU workspaces)
- **openssh**: SSH client (auto-configured)

## IDE & Extensions

### VS Code Web (Primary IDE)
- **Access**: Via Coder dashboard app (browser-based, no installation needed)
- **Theme**: Poimandres (dark theme)
- **Layout**: Right sidebar, top activity bar
- **Window Title**: "Riksarkivet IDE"

### Pre-installed Extensions
- `ms-python.python`: Python language support
- `anthropic.claude-code`: Claude AI integration (you!)
- `golang.Go`: Go language support
- `charliermarsh.ruff`: Python linting with Ruff
- `marimo-team.vscode-marimo`: Reactive notebook support
- `miguelsolorio.symbols`: Icon theme
- `redhat.vscode-yaml`: YAML support
- `tamasfe.even-better-toml`: TOML support
- `pmndrs.pmndrs`: Poimandres theme

### Additional Available Apps
- **File Browser**: Web-based file manager (accessible via Coder dashboard)
- **Web Terminal**: Terminal access via browser
- **Dotfiles**: Personal configuration management

## AI Assistant Integrations

### Claude Code (You!)
- **Web Interface**: Available via Coder module
- **API Key**: Configurable via workspace parameters
- **Custom Prompts**: Configurable via workspace parameters
- **Environment Variables**: 
  - `CODER_MCP_CLAUDE_API_KEY`: Your API key
  - `CODER_MCP_CLAUDE_TASK_PROMPT`: Custom user prompt

### Aider (Command-line AI coding)
- **Configuration**: `/home/coder/.aider.conf.yml`
- **Model**: `openai/all-hands/openhands-lm-32b-v0.1`
- **API Endpoint**: `http://llm-service.models:8000/v1`
- **Usage**: `aider` command for AI-assisted coding

### Continue (VS Code extension)
- **Configuration**: `/home/coder/.continue/config.yaml`
- **Model**: OpenHands Local (vLLM)
- **API Endpoint**: `http://llm-service.models:8000/v1`
- **Usage**: Integrated in VS Code for AI code completion

## Storage & File System

### Persistent Storage
- **Home Directory**: `/home/coder` (backed by Kubernetes PVC)
- **Size**: Configurable via workspace parameter (default: 10GB)

### Mounted Volumes
- **Scratch Space**: `/mnt/scratch` (temporary storage, hostPath mount)
- **Work Space**: `/mnt/work` (shared storage, hostPath mount)
- **Shared Memory**: `/dev/shm` (20% of pod memory allocation)

### Configuration Directories
- **SSH**: `/home/coder/.ssh` (auto-configured, keys loaded)
- **Kube Config**: `/home/coder/.kube` (limited cluster access)
- **Coder Config**: `/home/coder/.config/coderv2`
- **Continue Config**: `/home/coder/.continue`

## GPU Support (If Enabled)
- **Runtime**: NVIDIA Container Runtime
- **Available GPUs**: 
  - Quadro RTX 5000
  - NVIDIA RTX A5000  
  - NVIDIA RTX A6000
  - NVIDIA RTX 6000 Ada Generation
- **Monitoring**: `nvidia-smi`, `nvtop`
- **CUDA Compatibility**: PyTorch CUDA 12.1 builds supported

## External Service Integrations

### LakeFS (Data Versioning)
- **Configuration**: `/home/coder/.lakectl.yaml` (auto-generated)
- **Endpoint**: `http://lakefs.lakefs:80/`
- **Credentials**: Mounted from Kubernetes secret `lakefs-secrets`

### MLflow (Experiment Tracking)
- **Environment Variable**: `MLFLOW_TRACKING_URI` (if configured)
- **Access**: Via external URL (configurable via template variable)

### Argo Workflows
- **Environment Variable**: `ARGO_BASE_HREF` (if configured)
- **CLI**: `argo` command available
- **Access**: Via external URL (configurable via template variable)

## Git & SSH Configuration
- **Git User**: Auto-configured with Coder workspace owner details
- **SSH Agent**: Automatically started and configured
- **SSH Hosts**: Pre-configured for Azure DevOps, GitHub, and internal Git services
- **SSH Key**: Auto-generated or provided via workspace parameter
- **Known Hosts**: Disabled strict checking for common Git hosts

## Resource Allocation

### Configurable Parameters
- **CPU**: 2-24 cores (default: 2)
- **Memory**: 2-96 GB (default: 2GB)  
- **GPU Count**: 0-4 GPUs (default: 0)
- **Home Disk**: 1-99999 GB (default: 10GB)

### Resource Monitoring
- CPU, memory, disk usage metrics available
- GPU memory monitoring (if GPU enabled)
- Host-level resource monitoring

## Security Context
- **User Permissions**: Non-root execution (UID 1000)
- **Sudo Access**: Passwordless sudo available for system administration
- **Secret Management**: Kubernetes secrets for sensitive data
- **Network**: Pod-level isolation within Kubernetes cluster
- **Container Security**: Runs with security contexts and resource limits

## Environment Variables

### System Variables
- `HOME=/home/coder`
- `PATH` includes Python venv, Homebrew, and CUDA paths
- `LOGNAME`: Set to workspace owner name
- `KUBECONFIG=/home/coder/.kube/config`

### Dagger Build System
- `_EXPERIMENTAL_DAGGER_RUNNER_HOST=unix:///run/dagger/engine.sock`
- `DAGGER_NO_NAG=1`

### User-Configurable (via workspace parameters)
- `GH_TOKEN`: GitHub personal access token
- `HF_TOKEN`: Hugging Face access token  
- `DOCKER_PASSWORD`: Docker registry password

## Common Workflow Operations

### Starting a New ML Project
```bash
# Create new project with uv
uv init my-ml-project
cd my-ml-project

# Add dependencies
uv add torch numpy pandas scikit-learn
uv add transformers datasets

# Start development
code .  # Opens in VS Code web
```

### Container Builds with Dagger
```bash
# Build CPU version
dagger call build-cpu

# Build GPU version  
dagger call build-cuda

# Custom build from current directory
dagger call build-from-current-dir --enable-cuda=true --image-tag="custom"
```

### Working with Data
```bash
# LakeFS operations
lakefs branch list
lakefs commit

# DuckDB analysis
duckdb data.db "SELECT * FROM table LIMIT 10"
```

## Troubleshooting & Support

### Log Locations
- **Startup Logs**: Coder agent logs (visible in dashboard)
- **Application Logs**: Check individual application configurations

### Health Checks
- **Python Environment**: `python --version`, `which python`
- **CUDA**: `nvidia-smi` (GPU workspaces), `python -c "import torch; print(torch.cuda.is_available())"`
- **Tools**: Most tools available in `$PATH` via Homebrew

### Common Issues
- **Package Installation**: Use `uv add` instead of `pip install`
- **GPU Access**: Verify GPU type matches node labels
- **Secret Access**: Check if `lakefs-secrets` exists in namespace

## Development Best Practices
- Use the pre-configured Python virtual environment
- Leverage `uv` for fast package management
- Utilize SSH auto-configuration for Git operations
- Take advantage of persistent home directory for project storage
- Use AI assistants (Aider, Continue, Claude Code) for enhanced productivity
- Monitor resource usage via Coder dashboard metrics

## Version Information
- **Template Version**: Based on Riksarkivets-Development-Template v14.2.0+
- **Container Images**: `v14.2.0` (GPU), `v14.2.0-cpu` (CPU-only)
- **VS Code Module**: v1.3.1
- **Claude Code Module**: v2.0.3

This workspace is optimized for data science, machine learning, and AI development with comprehensive tooling and infrastructure support. All tools are pre-configured and ready to use.