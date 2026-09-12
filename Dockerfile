ARG CONTAINER_VARIANT=6.1.7-noble

FROM mcr.microsoft.com/devcontainers/universal:${CONTAINER_VARIANT}

USER root

RUN sudo apt-get update && sudo apt-get install -y \
    openssh-server sudo curl git vim tmux ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd

# devcontainers/universal already has a non-root "codespace" user;
# reuse it instead of creating a new one
RUN mkdir -p /home/codespace/.ssh \
    && chmod 700 /home/codespace/.ssh \
    && chown -R codespace:codespace /home/codespace/.ssh

# sshd config: key-only auth, no root login
RUN sed -i \
    -e 's/#PermitRootLogin.*/PermitRootLogin no/' \
    -e 's/#PasswordAuthentication.*/PasswordAuthentication no/' \
    -e 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' \
    /etc/ssh/sshd_config

USER codespace

ARG CLAUDE_CODE_VERSION=latest
ARG NODE_MAJOR=26
ARG GO_VERSION=1.25.10

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    curl \
    fzf \
    gh \
    git \
    gnupg \
    jq \
    less \
    openssh-client \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    unzip \
    zsh \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN ARCH="$(dpkg --print-architecture)" \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -o /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz

ENV HOME=/home/codespace
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1 \
    GOPATH=$HOME/go \
    PATH=/usr/local/go/bin:$HOME/.local/bin:$HOME/go/bin:$PATH

# Install Claude Code into /opt/claude (outside $HOME) so the binary survives a
# PersistentVolumeClaim mount over the user's home directory at runtime.
# Runtime config and auth state still live under $HOME/.claude and persist via
# the PVC.
RUN mkdir -p /opt/claude \
    && export HOME=/opt/claude \
    && curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_CODE_VERSION}" \
    && ln -s /opt/claude/.local/bin/claude /usr/local/bin/claude \
    && chmod -R a+rX /opt/claude

# WORKDIR /home/codespace
# USER codespace

# CMD ["bash"]

USER root
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
