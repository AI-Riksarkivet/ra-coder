# Stage 1: Base system setup
FROM registry.ra.se:5002/ubuntu:jammy AS base

ARG ENABLE_CUDA=true
ARG CUDA_VERSION_MAJOR_MINOR=12.2

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew" \
    VENV_PATH="/opt/venv-py312"

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
    fi

# Stage 3: Homebrew and tools (parallel to CUDA)
FROM base AS homebrew-stage
USER coder
WORKDIR /home/coder

RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)" && \
    brew tap treeverse/lakefs && \
    brew install \
        python@3.12 \
        node@22 \
        argo@3.6.7 \
        awscli@2.27.9 \
        helm@3.17.3 \
        kubectl@1.33.0 \
        lakefs@1.55.0 \
        pre-commit@4.2.0 \
        duckdb@1.2.2 \
        huggingface-cli@0.30.2 \
        ruff@0.11.8 \
        uv@0.7.2 \
        terraform@1.5.7 && \
    PATH="${HOMEBREW_PREFIX}/opt/node@22/bin:$PATH" ${HOMEBREW_PREFIX}/opt/node@22/bin/npm install -g @anthropic-ai/claude-code && \
    brew cleanup --prune=all

# Stage 4: Final assembly
FROM cuda-stage AS final
USER coder
WORKDIR /home/coder

# Copy Homebrew installation from previous stage
COPY --from=homebrew-stage --chown=coder:coder /home/linuxbrew /home/linuxbrew

# Configure shell environment - users can create their own Python environments
RUN echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ~/.profile && \
    echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ~/.bashrc

CMD ["/bin/bash"]