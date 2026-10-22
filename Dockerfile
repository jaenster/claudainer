FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Base packages and CLI tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essentials
    ca-certificates curl wget gnupg lsb-release \
    git git-lfs openssh-client sudo \
    # Build tools
    build-essential gcc g++ make cmake pkg-config \
    autoconf automake libtool \
    # CLI tools
    jq yq vim neovim nano tmux screen \
    htop btop ncdu tree \
    ripgrep fd-find fzf bat \
    zip unzip xz-utils \
    # Network tools
    dnsutils iputils-ping netcat-openbsd socat \
    # Misc
    locales tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Python
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# Node.js (via NodeSource)
ARG NODE_VERSION=22
ARG NODE_PINNED=22.23.4
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y "nodejs=${NODE_PINNED}-1nodesource1" \
    && npm install -g pnpm yarn \
    && rm -rf /var/lib/apt/lists/*

# Go
ARG GO_VERSION=1.23.2
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" \
    | tar -C /usr/local -xzf - \
    && echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile.d/go.sh

# Rust (system-wide)
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path \
    && chmod -R a+w $RUSTUP_HOME $CARGO_HOME \
    && echo 'export PATH=$PATH:/usr/local/cargo/bin' >> /etc/profile.d/rust.sh

# Docker CLI (for docker-out-of-docker)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Kubernetes tools
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update && apt-get install -y kubectl \
    && rm -rf /var/lib/apt/lists/*

# Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y terraform \
    && rm -rf /var/lib/apt/lists/*

# Zig
ARG ZIG_VERSION=0.13.0
RUN curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-$(uname -m)-${ZIG_VERSION}.tar.xz" \
    | tar -C /usr/local -xJf - \
    && ln -s /usr/local/zig-linux-$(uname -m)-${ZIG_VERSION}/zig /usr/local/bin/zig

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# 1Password CLI (headless via OP_SERVICE_ACCOUNT_TOKEN)
RUN curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
    | gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
    > /etc/apt/sources.list.d/1password.list \
    && apt-get update && apt-get install -y 1password-cli \
    && rm -rf /var/lib/apt/lists/*

# Chromium for puppeteer, via Playwright since it ships builds for amd64 and arm64
ARG PLAYWRIGHT_VERSION=1.55.0
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
RUN npx -y playwright@${PLAYWRIGHT_VERSION} install --with-deps chromium \
    && ln -s "$(find ${PLAYWRIGHT_BROWSERS_PATH} -type f -name chrome -path '*/chromium-*' | head -1)" /usr/local/bin/chromium \
    && chromium --version \
    && rm -rf /var/lib/apt/lists/* /root/.npm
ENV PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/chromium
ENV PUPPETEER_SKIP_DOWNLOAD=true

# MCP servers that are not run through npx
RUN npm install -g ts-lsp-mcp mongodb-mcp-server && rm -rf /root/.npm

# Configurable user
ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=dev
ARG USER_HOME=/home/dev

# Remove existing user with same UID if present, then create our user
RUN userdel -r $(getent passwd ${USER_UID} | cut -d: -f1) 2>/dev/null || true \
    && groupadd --gid ${USER_GID} ${USERNAME} 2>/dev/null || true \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -d ${USER_HOME} -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} \
    && usermod -aG docker ${USERNAME} 2>/dev/null || true

USER ${USERNAME}
WORKDIR ${USER_HOME}

# User-level PATH setup
RUN echo 'export PATH="$HOME/.local/bin:/usr/local/go/bin:/usr/local/cargo/bin:$PATH"' >> ~/.bashrc

# Claude Code native binary
# Also copied to /usr/local/bin so it survives a volume mounted over $HOME.
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && sudo cp "$(readlink -f ${USER_HOME}/.local/bin/claude)" /usr/local/bin/claude

# Remote Control entrypoint and GitHub token helpers (used by the k8s deployment)
COPY remote/ /opt/claudainer/

ENV PATH="${USER_HOME}/.local/bin:/usr/local/go/bin:/usr/local/cargo/bin:${PATH}"
ENV HOME="${USER_HOME}"

ENTRYPOINT ["claude"]
