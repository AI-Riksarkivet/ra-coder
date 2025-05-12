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

# Install CUDA Toolkit components
RUN apt-get install -y --no-install-recommends \
    cuda-nvcc-${CUDA_VERSION_MAJOR_MINOR} \
    cuda-cudart-dev-${CUDA_VERSION_MAJOR_MINOR} \
    cuda-libraries-dev-${CUDA_VERSION_MAJOR_MINOR} \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PATH=/usr/local/cuda-${CUDA_VERSION_MAJOR_MINOR}/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda-${CUDA_VERSION_MAJOR_MINOR}/lib64:${LD_LIBRARY_PATH}
# --- End CUDA Install ---

RUN  useradd coder \
    --create-home \
    --shell=/bin/bash \
    --uid=1000 \
    --user-group && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers.d/nopasswd

USER coder

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# Define paths for easier reference
ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV VENV_PATH="/opt/venv-py312"
ENV PATH="${VENV_PATH}/bin:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:${PATH}" 

# Switch to root to install system dependencies + utilities
USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gfortran \
    pkg-config \
    libopenblas-dev \
    libasound2-dev \
    htop \
    tree \
    unzip \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    && mkdir -p ${VENV_PATH} \
    && chown coder:coder ${VENV_PATH}

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
    helm \
    kubectl \
    lakefs \
    pre-commit \
    duckdb \
    huggingface-cli \
    ruff \
    uv && \
    brew cleanup --prune=all #&& \

RUN echo "Creating Python 3.12 virtual environment at ${VENV_PATH}..." && \
    ${HOMEBREW_PREFIX}/opt/python@3.12/bin/python3.12 -m venv ${VENV_PATH} && \
    echo "Activating venv and installing Python packages into ${VENV_PATH}..." && \
    eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)" && \
    source ${VENV_PATH}/bin/activate && \
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

RUN echo "Adding venv activation and brew shellenv to .profile and .bashrc..." && \
    echo ". ${VENV_PATH}/bin/activate" >> ~/.profile && \
    echo ". ${VENV_PATH}/bin/activate" >> ~/.bashrc && \
    echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ~/.profile && \
    echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ~/.bashrc
CMD ["/bin/bash"]