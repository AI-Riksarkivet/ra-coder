FROM ubuntu:jammy@sha256:ce4a593b4e323dcc3dd728e397e0a866a1bf516a1b7c31d6aa06991baec4f2e0

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew" \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1 \
    HOMEBREW_NO_CLEANUP_FORMULAE=1 \
    HOMEBREW_CLEANUP_PERIODIC_FULL_DAYS=3650

ENV PATH="${HOMEBREW_PREFIX}/opt/node@22/bin:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:${PATH}"

# Install base packages and create user
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash ca-certificates curl git jq locales sudo wget \
        build-essential && \
    locale-gen en_US.UTF-8 && \
    useradd coder --create-home --shell=/bin/bash --uid=1000 --user-group && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd && \
    chmod 440 /etc/sudoers.d/nopasswd && \
    mkdir -p /home/linuxbrew && chown coder:coder /home/linuxbrew && \
    rm -rf /var/lib/apt/lists/*

USER coder
WORKDIR /home/coder

# Install Homebrew and essential tools
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)" && \
    brew install \
        python@3.12 \
        node@22 \
        kubectl \
        k9s \
        uv \
        git \
        curl \
        jq && \
    PATH="${HOMEBREW_PREFIX}/opt/node@22/bin:$PATH" ${HOMEBREW_PREFIX}/opt/node@22/bin/npm install -g @anthropic-ai/claude-code && \
    brew cleanup --prune=all

# Copy CLAUDE.md workspace context file
COPY --chown=coder:coder workspace-claude.md /home/coder/CLAUDE.md

# Configure shell environment
RUN echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ~/.profile && \
    echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ~/.bashrc && \
    mkdir -p ~/.ssh && \
    chmod 700 ~/.ssh

CMD ["/bin/bash"]