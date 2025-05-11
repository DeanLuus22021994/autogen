# syntax=docker/dockerfile:1.4

# Base image with minimal dependencies
FROM mcr.microsoft.com/devcontainers/base:ubuntu as builder

# Optimize package installation with layer caching
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    apt-utils \
    build-essential \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    python3-dev \
    && apt-get autoremove -y \
    && apt-get clean -y

# Final image with optimized runtime
FROM builder AS final

# Set performance environment variables
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    DOTNET_EnableDiagnostics=0 \
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    PYTHONFAULTHANDLER=1 \
    # GPU passthrough support
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Create persistent cache directories
RUN mkdir -p /root/.cache/pip \
    && mkdir -p /root/.nuget/packages \
    && mkdir -p /root/.cache/uv \
    && mkdir -p /root/.vscode-server \
    && mkdir -p /tmp/docker-cache

# Add GPU detection script
COPY --chmod=0755 <<-"EOF" /usr/local/bin/detect-gpu
#!/bin/bash
echo "Checking for GPU availability..."
if [ -c /dev/nvidia0 ] || [ -d /proc/driver/nvidia ]; then
    echo "====================================="
    echo "🚀 NVIDIA GPU detected and available!"
    echo "====================================="
    export NVIDIA_VISIBLE_DEVICES=all
    export CUDA_VISIBLE_DEVICES=0
    if command -v nvidia-smi &> /dev/null; then
        echo "Driver information:"
        nvidia-smi --query-gpu=driver_version,name,temperature.gpu,utilization.gpu --format=csv
    fi
    echo "export NVIDIA_VISIBLE_DEVICES=all" >> ~/.bashrc
    echo "export CUDA_VISIBLE_DEVICES=0" >> ~/.bashrc
else
    echo "No NVIDIA GPU detected, running in CPU-only mode."
fi
EOF

# Add performance optimization for VS Code server
COPY --chmod=0755 <<-"EOF" /usr/local/bin/optimize-vscode
#!/bin/bash
echo "Optimizing VS Code Server performance..."
if [ -d /root/.vscode-server ]; then
    find /root/.vscode-server -name "*.js" -type f -exec touch {} \;
    find /root/.vscode-server -name "*.json" -type f -exec touch {} \;
fi
EOF

# Set up performance hooks
RUN echo "/usr/local/bin/detect-gpu" >> ~/.bashrc \
    && echo "/usr/local/bin/optimize-vscode" >> ~/.bashrc
