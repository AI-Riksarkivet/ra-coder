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
* **Core Libraries:**
    * **PyTorch:** Version 2.3.1 with CUDA 12.1 support (`torch`, `torchvision`, `torchaudio`).
    * **Data Science:** `numpy`, `pandas`, `scikit-learn`, `matplotlib`.
    * **Hugging Face:** `transformers`, `datasets`, `accelerate`.
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
3.  **Docker Image:** The Docker image defined by the `Dockerfile` (e.g., `registry.ra.se:5002/devenv:v8.0.0`) must be built and pushed to a registry accessible by your Kubernetes cluster. This template specifies `registry.ra.se:5002/devenv:v8.0.0`.
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

* **CPU:** The number of CPU cores for the workspace (e.g., "2", "4", "8"). Default: "2".
* **Memory:** The amount of memory in GB for the workspace (e.g., "4", "8", "16"). Default: "2".
* **Home disk size:** The size of the persistent home disk in GB. Default: "10". (Not mutable after creation).
* **GPU Type:** Select the type of GPU. Options: "None", "Quadro RTX 5000", "NVIDIA RTX A5000", "NVIDIA RTX A6000", "NVIDIA RTX 6000 Ada Generation". Default: "None". (Not mutable after creation).
* **Number of GPUs:** Number of GPUs to allocate (0-4). Ignored if GPU Type is "None". Default: "0". (Not mutable after creation).

## Input Variables (Configurable in the Coder Template UI)

* `use_kubeconfig` (bool): Set to `true` if Coder runs outside the Kubernetes cluster and should use `~/.kube/config` from the Coder host. Default: `false` (for in-cluster Coder).
* `namespace` (string): The Kubernetes namespace to create workspaces in. This namespace must exist.
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
* **Key Python Packages (in venv):**
    * `uv`: For Pip package management.
    * `torch==2.3.1+cu121`
    * `torchvision==0.18.1+cu121`
    * `torchaudio==2.3.1+cu121`
    * `numpy`, `pandas`, `scikit-learn`, `matplotlib`
    * `transformers`, `datasets`, `accelerate` (Hugging Face)
    * `mlflow` (MLOps)
    * `aider-chat` (AI Coding Assistant)
* **System Build Tools:** `build-essential`, `gfortran`, `pkg-config`, `libopenblas-dev`, `libasound2-dev`.

### Command-Line Tools (installed via Homebrew)
* `argo`
* `awscli`
* `helm`
* `kubectl`
* `lakefs`
* `pre-commit`
* `duckdb`
* `huggingface-cli`
* `ruff` (Python linter)
* General utilities: `jq`, `htop`, `tree`, `unzip`, `wget`, `curl`.

### IDE & Extensions
* **`code-server`:** VS Code in the browser, accessible via a Coder app.
* **Pre-installed VS Code Extensions:**
    * `charliermarsh.ruff` (Ruff Linter)
    * `exiasr.hadolint` (Dockerfile linter)
    * `kevinrose.vsc-python-indent` (Python Indentation)
    * `redhat.vscode-yaml` (YAML Support)
    * `shardulm94.trailing-spaces` (Trailing Spaces)
    * `pomdtr.excalidraw-editor` (Excalidraw Integration)
    * `tamasfe.even-better-toml` (TOML Language Support)
    * `PKief.material-icon-theme` (Material Icon Theme)
    * `mhutchie.git-graph` (Git Graph)
    * `Continue.continue` (AI Coding Assistant extension)
    * `marimo-team.vscode-marimo` (Marimo Notebook support)

### AI Assistants Configuration
* **Aider:** Configured via `/home/coder/.aider.conf.yml` to use the model `openai/all-hands/openhands-lm-32b-v0.1` at `http://llm-service.models:8000/v1`.
* **Continue (VS Code Extension):** Configured via `/home/coder/.continue/config.yaml` for the "OpenHands Local (vLLM)" model, also pointing to `http://llm-service.models:8000/v1`.

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

* **Image:** Uses the custom Docker image `registry.ra.se:5002/devenv:v8.0.0` (or as specified in `kubernetes_deployment.main.spec.template.spec.container.image`).
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

* **Code Server:** Provides access to the VS Code IDE at `http://localhost:13337?folder=/home/coder`.
* **Filebrowser:** A web-based file manager for the workspace.
* **Dotfiles:** Module to manage and apply your personal dotfiles.

## Agent Startup Script (`coder_agent.main.startup_script`)

The agent startup script performs several key actions:

1.  **Installs/Updates `code-server`:** Fetches and installs the latest standalone version of `code-server` to `/tmp/code-server`.
2.  **Configures Continue:** Creates `/home/coder/.continue/config.yaml` for the local LLM setup.
3.  **Configures `lakectl`:** Reads LakeFS credentials from the mounted secret `/etc/secrets/lakefs/` and writes `~/.lakectl.yaml`.
4.  **Configures Aider:** Creates `/home/coder/.aider.conf.yml` for the local LLM setup.
5.  **Installs VS Code Extensions:** Iterates through a list of predefined extensions and installs them using `code-server --install-extension`.
6.  **Configures Git:** Sets global `user.name` and `user.email` using Coder workspace owner details.
7.  **Starts `code-server`:** Launches `code-server` on `0.0.0.0:13337` without authentication.
8.  **Displays Service Info:** Prints MLflow and Argo UI addresses to the agent log if configured.

## How to Use

1.  **Import Template:** Add this template to your Coder deployment.
2.  **Build Docker Image:** Ensure the Dockerfile provided is built and pushed to the registry specified in `main.tf` (`registry.ra.se:5002/devenv:v8.0.0`). Modify the image tag in `main.tf` if you use a different one.
3.  **Create Kubernetes Secret:** Ensure the `lakefs-secrets` secret is created in the target Kubernetes namespace.
4.  **Create Workspace:**
    * Navigate to Coder and create a new workspace using this template.
    * Configure the workspace parameters (CPU, Memory, Disk, GPU).
    * Set template variables (namespace, external service URLs if any).
    * Coder will provision the Kubernetes resources and start the agent.
5.  **Connect:** Once the workspace is running, connect to it via the Coder dashboard, typically opening the `code-server` app.

## Customization

* **Software in Docker Image:** Modify the `Dockerfile` to add or remove system packages, Homebrew formulae, or Python libraries. Rebuild and push the image after changes.
* **VS Code Extensions:** Add or remove extension IDs from the `EXTENSIONS_STR` variable in the `coder_agent.main.startup_script` within `main.tf`.
* **LLM Configuration:**
    * Change the `apiBase` and `model` in `/home/coder/.continue/config.yaml` (within the startup script) for the Continue extension.
    * Change `openai-api-base` and `model` in `/home/coder/.aider.conf.yml` (within the startup script) for Aider.
* **Resource Allocation:** Adjust default values or ranges for `cpu`, `memory`, etc., in the `data "coder_parameter"` blocks in `main.tf`.
* **Kubernetes Manifests:** Modify the `kubernetes_deployment` or `kubernetes_persistent_volume_claim` resources in `main.tf` for advanced Kubernetes configurations.
* **Cloud CLIs:** Uncomment and install `azure-cli` or `google-cloud-sdk` in the Dockerfile if needed.