# build-tools-sidecar Dockerfile
# This container provides pre-initialized build tools for instant compilation
# of AutoGen code, supporting both .NET and Python projects

FROM mcr.microsoft.com/dotnet/sdk:6.0-focal

# Set labels for better container management
LABEL maintainer="AutoGen Team"
LABEL description="Build tools sidecar container for instant compilation"
LABEL org.opencontainers.image.source="https://github.com/microsoft/autogen"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    git \
    python3 \
    python3-pip \
    python3-dev \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install Python build tools
RUN pip3 install --no-cache-dir \
    uv \
    build \
    wheel \
    setuptools \
    twine \
    pre-commit

# Pre-warm the .NET SDK
RUN dotnet --info && \
    # Create and build a small sample project to pre-warm the SDK
    mkdir -p /tmp/warmup && \
    cd /tmp/warmup && \
    dotnet new console && \
    dotnet build && \
    dotnet publish -c Release && \
    rm -rf /tmp/warmup

# Install Node.js tools
RUN npm install -g markdownlint-cli2 --no-fund --no-audit

# Create directory for mounting workspace
RUN mkdir -p /workspace
WORKDIR /workspace

# Create volume for workspace mounting
VOLUME ["/workspace"]

# Add helper scripts
COPY ./scripts/build-dotnet.sh /usr/local/bin/
COPY ./scripts/build-python.sh /usr/local/bin/
COPY ./scripts/lint-markdown.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/build-dotnet.sh \
    /usr/local/bin/build-python.sh \
    /usr/local/bin/lint-markdown.sh

# Set health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD dotnet --info > /dev/null

# Default command
CMD ["sh", "-c", "echo 'Build tools sidecar container is running'; tail -f /dev/null"]
