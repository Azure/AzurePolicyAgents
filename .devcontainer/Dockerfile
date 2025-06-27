# Base image switched to azure-powershell
FROM mcr.microsoft.com/azure-powershell:latest

# Install essential packages and tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip ca-certificates zsh jq git sudo python3-pip \
    && curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && curl -Lo /usr/local/bin/bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 \
    && chmod +x /usr/local/bin/bicep \
    && pip3 install pre-commit \
    && rm -rf /var/lib/apt/lists/*

# Non-root user setup
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/pwsh --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set user context
USER $USERNAME