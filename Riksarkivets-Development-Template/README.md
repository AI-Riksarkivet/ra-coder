# Coder Template: GPU-Accelerated Data Science & MLOps Environment

This Coder template provisions a comprehensive development environment tailored for GPU-accelerated data science, machine learning, and MLOps tasks. It leverages Docker for image creation and Terraform for deploying the workspace on Kubernetes.

The environment comes pre-configured with CUDA, Python, PyTorch, popular data science libraries, MLOps tools, an AI coding assistant (Aider), and the Continue extension for VS Code, all integrated with a local/network-accessible Large Language Model (LLM).

## Features

* **Base OS:** Ubuntu 22.04 LTS (Jammy).
* **CUDA Enabled:** NVIDIA CUDA Toolkit 12.2 installed in the Docker image, supporting applications built with CUDA 12.1 (like PyTorch).
* **Python Environment:**
    * Python 3.12 installed via Homebrew.
    * Dedicated virtual environment (`/opt/venv-py312`) managed by `uv`.
    * Auto-activated venv and Homebrew shell environment upon terminal login.
* **ML Package Support:**
    * **PyTorch Ready:** CUDA 12.2 environment compatible with PyTorch CUDA 12.1 builds
    * **Fast Package Installation:** Use `uv` for quick ML package installation
    * **Framework Flexibility:** Install any ML framework (PyTorch, TensorFlow, JAX, etc.) as needed
* **MLOps Tools:**
    * `mlflow` (client library).
    * `lakefs` (client CLI, configured via secrets).
    * `argo` (client CLI).
* **Development Tools:**
    * `code-server` (VS Code in the browser) as the primary IDE.
    * Homebrew for package management.
    * Git, `pre-commit`, `ruff`, `huggingface-cli`, `duckdb`.
    * Kubernetes tools: `kubectl`, `helm`.
    * Cloud CLIs: `awscli` (Azure and Google Cloud CLIs can be uncommented in Dockerfile).
* **AI-Assisted Development:**
    * `aider-chat`: Command-line AI coding assistant.
    * `Continue`: VS Code extension for AI coding.
    * Both are pre-configured to use a local/network-accessible vLLM OpenHands model (configurable).
* **Kubernetes Deployment:**
    * Persistent home directory via Kubernetes Persistent Volume Claim (PVC).
    * Customizable CPU, memory, and home disk size.
    * Optional NVIDIA GPU support with configurable type and count.
    * HostPath mounts for `/mnt/scratch` and `/mnt/work`.
    * LakeFS credentials mounted from a Kubernetes secret.
* **Coder Integration:**
    * Coder apps for `code-server`, `filebrowser`, and `dotfiles`.
    * Workspace parameters for easy customization.
    * Metadata for monitoring workspace resources.

## Prerequisites

Before using this template, ensure you have:

1.  **Coder Server:** A Coder v2 instance deployed and accessible.
2.  **Kubernetes Cluster:**
    * Accessible by the Coder deployment.
    * If using GPUs:
        * NVIDIA GPU drivers installed on the nodes.
        * NVIDIA Container Toolkit (or equivalent like `nvidia-docker2`) and the `nvidia` runtime class configured.
        * Nodes labeled appropriately (e.g., `nvidia.com/gpu.product: NVIDIA-RTX-A6000`) if specific GPU types are targeted.
3.  **Docker Image:** The Docker image defined by the `Dockerfile` (e.g., `registry.ra.se:5002/airiksarkivet/devenv:v13.4.0`) must be built and pushed to a registry accessible by your Kubernetes cluster. This template specifies `registry.ra.se:5002/airiksarkivet/devenv:v13.4.0`.
4.  **Kubernetes Namespace:** The Kubernetes namespace specified by the `namespace` variable (e.g., `coder`) must exist.
5.  **LakeFS Secret (Required for LakeFS integration):**
    * A Kubernetes secret named `lakefs-secrets` must exist in the **same namespace** where workspaces will be deployed.
    * This secret must contain the following keys:
        * `access_key_id`: Your LakeFS access key ID.
        * `secret_access_key`: Your LakeFS secret access key.
6.  **Host Directories (Optional but configured):**
    * If you intend to use the `/mnt/scratch` and `/mnt/work` hostPath mounts, ensure these directories exist on the Kubernetes nodes where workspaces may be scheduled and have appropriate permissions.
7.  **LLM Service (For Aider & Continue):**
    * An OpenAI-compatible API endpoint for a Large Language Model. The default configuration points to `http://llm-service.models:8000/v1` using the model `all-hands/openhands-lm-32b-v0.1`. This service needs to be accessible from the workspace pods.
8.  **External Services (Optional):**
    * If you plan to use MLflow or Argo Workflows integration, ensure these services are deployed and their UI addresses are accessible.

## Workspace Parameters (Configurable at Workspace Creation)

* **CPU:** The number of CPU cores for the workspace (2, 4, 6, 8, 12, 16, 20, 24). Default: "2".
* **Memory:** The amount of memory in GB for the workspace (2, 4, 6, 8, 16, 32, 64, 96). Default: "2".
* **Home disk size:** The size of the persistent home disk in GB (1-99999). Default: "10". (Not mutable after creation).
* **GPU Type:** Select the type of GPU. Options: "None", "Quadro RTX 5000", "NVIDIA RTX A5000", "NVIDIA RTX A6000", "NVIDIA RTX 6000 Ada Generation". Default: "None". (Not mutable after creation).
* **Number of GPUs:** Number of GPUs to allocate (0-4). Ignored if GPU Type is "None". Default: "0". (Not mutable after creation).
* **AI Prompt:** Custom prompt for Claude Code integration. Default: "". (Mutable).
* **Anthropic API Key:** Your Anthropic API key for Claude Code. Default: "". (Mutable).
* **GitHub Token:** GitHub personal access token for API access. Default: "". (Mutable).
* **Hugging Face Token:** Hugging Face access token for CLI and API access. Default: "". (Mutable).

## Input Variables (Configurable in the Coder Template UI)

* `use_kubeconfig` (bool): Set to `true` if Coder runs outside the Kubernetes cluster and should use `~/.kube/config` from the Coder host. Default: `false` (for in-cluster Coder).
* `namespace` (string): The Kubernetes namespace to create workspaces in. This namespace must exist.
* `container_registry` (string): The container registry URL for workspace images (e.g., `registry.example.com:5000`). Default: `"registry.ra.se:5002"`.
* `mlflow_external_address` (string): External URL for the MLflow Tracking Server UI (e.g., `http://mlflow.example.com`). Leave empty to disable MLflow app and environment variable injection. Default: `""`.
* `argowf_external_address` (string): External URL for the Argo Workflow Server UI (e.g., `http://argo.example.com`). Leave empty to disable Argo Workflow app and environment variable injection. Default: `""`.

## Included Software & Tools

### OS & System
* Ubuntu 22.04 LTS (Jammy)
* NVIDIA CUDA Toolkit 12.2
* `coder` user (UID 1000) with passwordless sudo

### Development Environment
* **Homebrew:** Installed for the `coder` user at `/home/linuxbrew/.linuxbrew`.
    * Python 3.12 (`python@3.12`)
* **Python Virtual Environment:** Located at `/opt/venv-py312`.
    * Created using Python 3.12 and `uv`.
    * Automatically activated in new shells.
* **Python Package Management:**
    * `uv`: Fast Python package installer and resolver (pre-installed)
    * **Virtual environment**: Pre-configured at `/opt/venv-py312` (auto-activated)
    * **Package installation**: Users install packages as needed using `uv add <package>`
    * **CUDA-compatible PyTorch**: Install with `uv add torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121`
    * **Common ML packages**: Install as needed (numpy, pandas, scikit-learn, transformers, etc.)
* **System Build Tools:** `build-essential`, `gfortran`, `pkg-config`, `libopenblas-dev`, `libasound2-dev`.

### Command-Line Tools (installed via Homebrew)
* **Kubernetes & Cloud:**
  * `kubectl` - Kubernetes CLI
  * `helm` - Kubernetes package manager
  * `k9s` - Kubernetes TUI
  * `argo` - Argo Workflows CLI
  * `awscli` - AWS CLI
* **Development & ML:**
  * `ruff` - Python linter and formatter
  * `pre-commit` - Git hooks management
  * `huggingface-cli` - Hugging Face Hub CLI
  * `lakefs` - Data versioning CLI
  * `duckdb` - In-process analytical database
  * `uv` - Fast Python package installer
  * `terraform` - Infrastructure as Code tool
  * `gh` - GitHub CLI
* **System Utilities:**
  * `jq`, `htop`, `tree`, `unzip`, `wget`, `curl`, `vim`, `nano`

### IDE & Extensions
* **VS Code Web:** Browser-based VS Code accessible via Coder app (no desktop installation required).
* **Core VS Code Extensions (automatically installed):**
    * `ms-python.python` - Python language support
    * `ms-python.debugpy` - Python debugging
    * `anthropic.claude-code` - Claude AI integration
* **Additional Extensions (available in documentation):**
    * Python development: Ruff linter, Python indentation
    * Infrastructure: Dockerfile linter (Hadolint), YAML support  
    * Productivity: Git Graph, Material Icon Theme, trailing spaces
    * AI: Continue extension for local LLM integration
    * Notebooks: Marimo reactive notebook support
    * Visualization: Excalidraw editor integration

### AI Assistants Configuration
* **Aider:** Configured via `/home/coder/.aider.conf.yml` to use the model `openai/all-hands/openhands-lm-32b-v0.1` at `http://llm-service.models:8000/v1`.
* **Continue (VS Code Extension):** Configured via `/home/coder/.continue/config.yaml` for the "OpenHands Local (vLLM)" model, also pointing to `http://llm-service.models:8000/v1`.
* **Claude Code:** Integrated via Coder module with configurable API key and prompts through workspace parameters.

## Configuration Details

* **User:** Workspaces run as the `coder` user (UID 1000, GID 1000).
* **Environment Activation:** `.profile` and `.bashrc` are configured to automatically:
    * Activate the Python virtual environment (`${VENV_PATH}/bin/activate`).
    * Initialize the Homebrew environment (`eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"`).
* **CUDA Environment Variables:**
    * `PATH`: Includes `/usr/local/cuda-12.2/bin`.
    * `LD_LIBRARY_PATH`: Includes `/usr/local/cuda-12.2/lib64`.
* **LakeFS CLI (`lakectl`):**
    * Configured via `~/.lakectl.yaml` during agent startup.
    * Credentials (`access_key_id`, `secret_access_key`) are read from `/etc/secrets/lakefs/`.
    * Server endpoint set to `http://lakefs.lakefs:80/`.
* **Git:** `user.name` and `user.email` are automatically configured based on the Coder workspace owner's information.

## Kubernetes Deployment Details

* **Image:** Uses the custom Docker image `registry.ra.se:5002/airiksarkivet/devenv:v13.4.0` (GPU) or `registry.ra.se:5002/airiksarkivet/devenv:v13.4.0-cpu` (CPU-only) as specified in the deployment configuration.
* **Persistent Storage:**
    * `/home/coder` is backed by a `PersistentVolumeClaim` named `coder-<workspace-id>-home`. The size is determined by the `home_disk_size` parameter.
* **GPU Support:**
    * If a GPU type and count (>0) are selected:
        * The pod `runtime_class_name` is set to `nvidia`.
        * Node affinity rules ensure the pod is scheduled on a node with the specified GPU product (e.g., `NVIDIA-RTX-A6000`) via the `nvidia.com/gpu.product` label.
        * The `nvidia.com/gpu` resource is requested and limited according to the selected GPU count.
* **Mounted Volumes:**
    * `/home/coder`: User's persistent home directory (PVC).
    * `/etc/secrets/lakefs`: Mounts the `lakefs-secrets` Kubernetes secret for LakeFS credentials.
    * `/mnt/scratch`: HostPath mount to `/mnt/scratch/` on the Kubernetes node (read-write).
    * `/mnt/work`: HostPath mount to `/mnt/work/` on the Kubernetes node (read-write).
* **Resource Allocation:**
    * Requests: CPU "250m", Memory "512Mi" (plus GPU if selected).
    * Limits: Configurable via `cpu` and `memory` workspace parameters (plus GPU if selected).
* **Security Context:** Pods run with `runAsUser: 1000`, `fsGroup: 1000`, and `runAsNonRoot: true`.

## Coder Apps

* **VS Code Web:** Provides access to the VS Code IDE via Coder app (port 13338 internally).
* **File Browser:** A web-based file manager for the workspace (port 13339 internally).
* **Claude Code:** Anthropic's AI coding assistant with web interface and CLI integration.
* **Dotfiles:** Module to manage and apply your personal dotfiles.

## Agent Startup Script (`coder_agent.main.startup_script`)

The agent startup script performs several key actions:

1.  **Configures Continue:** Creates `/home/coder/.continue/config.yaml` for the local LLM setup with OpenHands model.
2.  **Configures LakeFS:** Reads LakeFS credentials from the mounted secret `/etc/secrets/lakefs/` and writes `~/.lakectl.yaml`.
3.  **Configures Aider:** Creates `/home/coder/.aider.conf.yml` for the local LLM setup.
4.  **Configures Git:** Sets global `user.name` and `user.email` using Coder workspace owner details.
5.  **Configures Coder CLI:** Sets up basic Coder CLI configuration.
6.  **Displays Service Info:** Prints MLflow and Argo UI addresses to the agent log if configured.

## How to Use

1.  **Import Template:** Add this template to your Coder deployment.
2.  **Build Docker Image:** Ensure the Dockerfile provided is built and pushed to the registry specified in `main.tf` (`registry.ra.se:5002/airiksarkivet/devenv:v14.0.0`). Use the Dagger build system: `dagger call build-cuda --dockerfile-content="$(cat Dockerfile)"` or modify the image tag in `main.tf` if you use a different one.
3.  **Create Kubernetes Secret:** Ensure the `lakefs-secrets` secret is created in the target Kubernetes namespace.
4.  **Create Workspace:**
    * Navigate to Coder and create a new workspace using this template.
    * Configure the workspace parameters (CPU, Memory, Disk, GPU).
    * Set template variables (namespace, external service URLs if any).
    * Coder will provision the Kubernetes resources and start the agent.
5.  **Connect:** Once the workspace is running, connect to it via the Coder dashboard, typically opening the VS Code Web app.

## Getting Started

### Installing Python Packages
The workspace comes with a pre-configured Python 3.12 virtual environment and `uv` package manager:

```bash
# Install PyTorch with CUDA support
uv add torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install common data science packages
uv add numpy pandas scikit-learn matplotlib seaborn

# Install Hugging Face ecosystem
uv add transformers datasets accelerate

# Install MLOps tools
uv add mlflow wandb

# Install AI coding assistant
uv add aider-chat

# Create a project with dependencies
uv init my-ml-project
cd my-ml-project
uv add torch transformers numpy
```

### Quick Start Commands
```bash
# Check Python and UV versions
python --version
uv --version

# Verify CUDA availability (if GPU workspace)
python -c "import torch; print(torch.cuda.is_available())"

# Start a new ML project
uv init my-project
cd my-project
uv add torch numpy matplotlib
```

## Build System

This template uses a modern Git-based Dagger + Kaniko build pipeline with automatic SSH key detection and no caching for maximum reliability:

### Quick Start
```bash
# CUDA build (production) - SSH key auto-detected from ~/.ssh/id_rsa
dagger call build-cuda --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"

# CPU build (development)
dagger call build-cpu --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"

# Custom version from specific branch/tag
dagger call build-from-git --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" --git-ref="v14.1.1" --image-tag=v14.1.1
```

### Key Features
- **🔑 Auto SSH Key Detection**: Automatically uses `~/.ssh/id_rsa` for Git authentication
- **🚫 Caching Disabled**: No cache-related issues, every build is fresh and reliable
- **📁 Git-Based**: All builds use Git repository as source of truth
- **⚡ Simplified**: Single `build-from-git` function with shortcuts

### Documentation
* **[BUILD.md](BUILD.md)** - Complete build guide with examples
* **[MIGRATION.md](MIGRATION.md)** - Migration from old Argo system
* **[BUILD-QUICK-REFERENCE.md](BUILD-QUICK-REFERENCE.md)** - Command reference card

### Key Benefits
* ✅ **No Argo dependency** - Direct Dagger execution
* ✅ **No size limits** - Direct Dockerfile reading
* ✅ **Better debugging** - Real-time build output
* ✅ **Same results** - Identical images using Kaniko backend

## Customization

* **Software in Docker Image:** Modify the `Dockerfile` to add or remove system packages, Homebrew formulae, or Python libraries. Use the Dagger build system to rebuild and push images: `dagger call build-cuda --dockerfile-content="$(cat Dockerfile)"`
* **LLM Configuration:**
    * Change the `apiBase` and `model` in `/home/coder/.continue/config.yaml` (within the startup script) for the Continue extension.
    * Change `openai-api-base` and `model` in `/home/coder/.aider.conf.yml` (within the startup script) for Aider.
* **Resource Allocation:** Adjust default values or ranges for `cpu`, `memory`, etc., in the `data "coder_parameter"` blocks in `main.tf`.
* **Kubernetes Manifests:** Modify the `kubernetes_deployment` or `kubernetes_persistent_volume_claim` resources in `main.tf` for advanced Kubernetes configurations.
* **Registry Configuration:** Use the `container_registry` template variable to configure a different registry, or override via environment variables (`REGISTRY` for build tools).
* **Cloud CLIs:** Uncomment and install `azure-cli` or `google-cloud-sdk` in the Dockerfile if needed.

## Security Features

* **Container Security:** Runs as non-root user (UID 1000) with restricted permissions
* **Secret Management:** LakeFS credentials mounted from Kubernetes secrets  
* **Network Isolation:** Pod-level network policies (configurable)
* **RBAC Integration:** Limited Kubernetes permissions via service account
* **Token Management:** Secure handling of API tokens through workspace parameters

## Monitoring and Observability

The template includes comprehensive resource monitoring:

* **Resource Metrics:** CPU, memory, and disk usage (container and host)
* **Update Intervals:** 10-60 seconds for different metrics
* **GPU Monitoring:** Resource allocation tracking (utilization monitoring available as enhancement)
* **Service Health:** Automatic service discovery and health reporting

## Version Information

**Current Template Versions:**
* **Container Image:** `v13.4.0` (CUDA), `v13.4.0-cpu` (CPU-only)
* **VS Code Web Module:** `1.3.1`
* **File Browser Module:** `1.0.30`  
* **Claude Code Module:** `2.0.3`
* **Dotfiles Module:** `1.0.29`

## Support and Documentation

For additional information, see:
* **issues.md** - Known issues and troubleshooting
* **features.md** - Missing features and enhancement suggestions  
* **overview.md** - Complete tool inventory and configuration details
* **CLAUDE.md** - Project context and development notes