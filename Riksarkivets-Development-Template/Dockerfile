# --- CHANGE 1: Switch base image to Ubuntu 22.04 LTS (Jammy) ---
# This version has CUDA Toolkit 12.2 available in NVIDIA's repos and is compatible
# with the host driver version 535.183.01 reported earlier.
FROM ubuntu:jammy

USER root
ENV DEBIAN_FRONTEND=noninteractive
# Combine initial package installs, add wget needed for CUDA repo setup
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    locales \
    sudo \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Generate the desired locale (en_US.UTF-8)
RUN locale-gen en_US.UTF-8

# Make typing unicode characters in the terminal work.
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# --- CHANGE 2: Install NVIDIA CUDA Toolkit 12.2 ---
# Install CUDA Toolkit compatible with the host driver (535.183.01 supports up to 12.2)
# Reference: https://developer.nvidia.com/cuda-12-2-0-download-archive?target_os=Linux&target_arch=x86_64&Distribution=Ubuntu&target_version=22.04&target_type=deb_network
ARG CUDA_VERSION_MAJOR_MINOR=12.2
ARG CUDA_DISTRO=ubuntu2204
ARG CUDA_ARCH=x86_64

# Add NVIDIA GPG keys and repository
RUN apt-get update && \
    # Ensure dependencies for adding repos are present (wget installed above)
    apt-get install -y --no-install-recommends gnupg2 && \
    wget https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DISTRO}/${CUDA_ARCH}/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    rm cuda-keyring_1.1-1_all.deb && \
    apt-get update

# Install CUDA Toolkit components (Compiler + Dev Libraries is usually sufficient)
# Using specific components instead of full cuda-toolkit-* saves space
RUN apt-get install -y --no-install-recommends \
    cuda-nvcc-${CUDA_VERSION_MAJOR_MINOR} \
    cuda-cudart-dev-${CUDA_VERSION_MAJOR_MINOR} \
    cuda-libraries-dev-${CUDA_VERSION_MAJOR_MINOR} \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set environment variables globally for CUDA
ENV PATH=/usr/local/cuda-${CUDA_VERSION_MAJOR_MINOR}/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda-${CUDA_VERSION_MAJOR_MINOR}/lib64:${LD_LIBRARY_PATH}
# --- End CUDA Install ---


# Remove the `ubuntu` user and add a user `coder` so that you're not developing as the `root` user
RUN  useradd coder \
    --create-home \
    --shell=/bin/bash \
    --uid=1000 \
    --user-group && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers.d/nopasswd

USER coder

# Set shell to bash for better compatibility and error handling (-e: exit on error)
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# Define paths for easier reference
ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
# Define virtual environment path using Python 3.12
ENV VENV_PATH="/opt/venv-py312"

# Add Venv and Homebrew paths to the system PATH
# Order matters: Venv, Homebrew, CUDA (already added via ENV above), then original PATH
ENV PATH="${VENV_PATH}/bin:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:${PATH}" 

# Switch to root to install system dependencies + utilities
USER root
# Combine apt-get operations, use --no-install-recommends, add utilities, cleanup
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gfortran \
    pkg-config \
    libopenblas-dev \
    libasound2-dev \
    # curl, file, git, procps already installed or handled earlier
    # Added Utilities
    htop \
    tree \
    unzip \
    # jq already installed earlier
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    # Create venv directory and give coder user ownership
    && mkdir -p ${VENV_PATH} \
    && chown coder:coder ${VENV_PATH}

# Switch back to the non-root coder user as soon as possible
USER coder
WORKDIR /home/coder

# Install Homebrew as the coder user
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install brew packages including Python 3.12, infra/DX tools, lakefs, argo, uv
# Ensure PATH includes Homebrew before running brew commands
RUN eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)" && \
    brew tap treeverse/lakefs && \
    brew install \
    python@3.12 \
    argo \
    awscli \
    # azure-cli \ # Uncomment if needed
    # google-cloud-sdk \ # Uncomment if needed
    helm \
    kubectl \
    lakefs \
    pre-commit \
    duckdb \
    huggingface-cli \
    ruff \
    uv && \
    brew cleanup --prune=all #&& \
    # Verification commands removed for brevity during update, add back if desired

# Create venv using Python 3.12, activate it, and install ALL Python packages into it
# NOTE: Pinning package versions is strongly recommended
RUN echo "Creating Python 3.12 virtual environment at ${VENV_PATH}..." && \
    # Use the explicit python 3.12 installed by brew to create the venv
    ${HOMEBREW_PREFIX}/opt/python@3.12/bin/python3.12 -m venv ${VENV_PATH} && \
    # Activate venv and install packages
    echo "Activating venv and installing Python packages into ${VENV_PATH}..." && \
    # Ensure brew paths are available if needed during pip install
    eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)" && \
    source ${VENV_PATH}/bin/activate && \
    # Now use uv to install the rest
    # --- CHANGE 3: Install PyTorch with CUDA 12.1 support ---
    # CUDA Toolkit 12.2 runtime supports applications built with CUDA 12.1
    # Check PyTorch website (pytorch.org) for latest stable versions compatible with CUDA 12.1
    uv pip install --no-cache \
    torch==2.3.1+cu121 torchvision==0.18.1+cu121 torchaudio==2.3.1+cu121 --index-url https://download.pytorch.org/whl/cu121 \
    # --- Core Data Science ---
    numpy \
    pandas \
    scikit-learn \
    matplotlib \
    # --- Hugging Face ---
    transformers \
    datasets \
    accelerate \
    # --- MLOps (as specified) ---
    mlflow \
    # --- AI Coding Assistant ---
    aider-chat \
    # --- Clean Cache ---
    && rm -rf /tmp/uv-cache # && \
    # --- Verification commands removed for brevity, add back if desired ---

# Add main venv activation AND brew shellenv to the coder user's bash profile/rc
RUN echo "Adding venv activation and brew shellenv to .profile and .bashrc..." && \
    echo ". ${VENV_PATH}/bin/activate" >> ~/.profile && \
    echo ". ${VENV_PATH}/bin/activate" >> ~/.bashrc && \
    echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ~/.profile && \
    echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ~/.bashrc

# Set the default command to start an interactive bash shell
# This shell should automatically activate the Python 3.12 venv
CMD ["/bin/bash"]