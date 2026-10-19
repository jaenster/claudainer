FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    openssh-client \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Configurable user - override at build time for custom paths
ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=dev
ARG USER_HOME=/home/dev

# Create group and user with custom home directory
RUN groupadd --gid ${USER_GID} ${USERNAME} 2>/dev/null || groupadd ${USERNAME} || true \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -d ${USER_HOME} ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR ${USER_HOME}

# Install Claude Code native binary
RUN curl -fsSL https://claude.ai/install.sh | bash

# Ensure claude is in PATH - use the actual home path
ENV PATH="${USER_HOME}/.local/bin:${PATH}"
ENV HOME="${USER_HOME}"

ENTRYPOINT ["claude"]
