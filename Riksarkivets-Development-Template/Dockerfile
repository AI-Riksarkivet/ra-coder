FROM ubuntu:jammy AS base

ARG ENABLE_CUDA=true
ARG CUDA_VERSION_MAJOR_MINOR=12.2

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew" \
    VENV_PATH="/opt/venv-py312" \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1 \
    HOMEBREW_NO_CLEANUP_FORMULAE=1 \
    HOMEBREW_CLEANUP_PERIODIC_FULL_DAYS=3650

ENV PATH="${VENV_PATH}/bin:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:${PATH}"

# Install base packages and create user
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash ca-certificates curl git jq locales sudo wget \
        build-essential gfortran pkg-config libopenblas-dev \
        libasound2-dev htop tree unzip && \
    locale-gen en_US.UTF-8 && \
    useradd coder --create-home --shell=/bin/bash --uid=1000 --user-group && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd && \
    chmod 440 /etc/sudoers.d/nopasswd && \
    mkdir -p ${VENV_PATH} && chown coder:coder ${VENV_PATH} && \
    mkdir -p /home/linuxbrew && chown coder:coder /home/linuxbrew && \
    rm -rf /var/lib/apt/lists/*

# Stage 2: CUDA installation (conditional)
FROM base AS cuda-stage
RUN if [ "$ENABLE_CUDA" = "true" ]; then \
        apt-get update && \
        apt-get install -y --no-install-recommends gnupg2 && \
        wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
        dpkg -i cuda-keyring_1.1-1_all.deb && rm cuda-keyring_1.1-1_all.deb && \
        apt-get update && \
        apt-get install -y --no-install-recommends \
            cuda-nvcc-${CUDA_VERSION_MAJOR_MINOR} \
            cuda-cudart-dev-${CUDA_VERSION_MAJOR_MINOR} \
            cuda-libraries-dev-${CUDA_VERSION_MAJOR_MINOR} && \
        apt-get clean && rm -rf /var/lib/apt/lists/*; \
    else \
        echo "CUDA disabled, skipping CUDA installation"; \
    fi

# Coder user already exists from base stage - ensure no duplication
USER coder
WORKDIR /home/coder

# Stage 3: Homebrew and tools (parallel to CUDA)
FROM base AS homebrew-stage
USER coder
WORKDIR /home/coder

RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)" && \
    brew tap treeverse/lakefs && \
    brew tap dagger/tap && \
    brew install \
        python@3.12 \
        node@22 \
        go \
        argo \
        awscli \
        azure-cli \
        helm \
        kubectl \
        k9s \
        lakefs \
        pre-commit \
        duckdb \
        huggingface-cli \
        ruff \
        vim \
        gh \
        nano \
        uv \
        terraform \
        nvtop \
        dagger \
        ripgrep \
        openssh && \
    PATH="${HOMEBREW_PREFIX}/opt/node@22/bin:$PATH" ${HOMEBREW_PREFIX}/opt/node@22/bin/npm install -g @anthropic-ai/claude-code && \
    brew cleanup --prune=all

# Stage 4: Final assembly
FROM cuda-stage AS final
# USER and WORKDIR already set in cuda-stage

# Copy Homebrew installation from previous stage
COPY --from=homebrew-stage --chown=coder:coder /home/linuxbrew /home/linuxbrew

# Copy CLAUDE.md workspace context file
COPY --chown=coder:coder workspace-claude.md /home/coder/CLAUDE.md

# Configure shell environment - users can create their own Python environments
RUN echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ~/.profile && \
    echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ~/.bashrc && \
    mkdir -p ~/.ssh && \
    chmod 700 ~/.ssh

CMD ["/bin/bash"]