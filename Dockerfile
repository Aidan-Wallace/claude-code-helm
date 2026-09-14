ARG CONTAINER_VARIANT=6.1.7-noble
ARG CLAUDE_CODE_VERSION=latest

FROM mcr.microsoft.com/devcontainers/universal:${CONTAINER_VARIANT}

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
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
    openssh-server \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    sudo \
    supervisor \
    tmux \
    unzip \
    vim \
    zsh \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd

RUN mkdir -p /home/codespace/.ssh \
    && chmod 700 /home/codespace/.ssh \
    && chown -R codespace:codespace /home/codespace/.ssh

# ever gets mounted over it - entrypoint.sh reseeds from this on first boot
RUN cp -a /home/codespace /opt/skel-codespace

RUN sed -i \
    -e 's/#PermitRootLogin.*/PermitRootLogin no/' \
    -e 's/#PasswordAuthentication.*/PasswordAuthentication no/' \
    -e 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' \
    -e 's/^Port .*/Port 22/' \
    -e 's/#LogLevel.*/LogLevel VERBOSE/' \
    /etc/ssh/sshd_config

RUN sed -i 's#^PATH="#PATH="/home/codespace/nvm/current/bin:/usr/local/go/bin:#' /etc/environment

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

COPY docker/sshd.supervisor.conf /etc/supervisor/conf.d/sshd.conf
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER root
EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
