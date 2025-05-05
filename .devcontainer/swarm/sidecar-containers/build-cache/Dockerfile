# build-cache-sidecar Dockerfile
# This container provides dependency caching for instant builds
# of .NET and Python projects in the AutoGen development environment

FROM alpine:3.17

# Set labels for better container management
LABEL maintainer="AutoGen Team"
LABEL description="Build cache sidecar container for instant builds"
LABEL org.opencontainers.image.source="https://github.com/microsoft/autogen"

# Install required utilities
RUN apk add --no-cache \
    ca-certificates \
    bash \
    curl \
    jq \
    rsync

# Create cache directories with appropriate permissions
RUN mkdir -p \
    /cache/dotnet \
    /cache/dotnet/nuget \
    /cache/python \
    /cache/python/pip \
    /cache/python/uv \
    /cache/npm && \
    chmod -R 777 /cache

# Set up volume for persistent cache storage
VOLUME ["/cache"]

# Add cache management scripts
COPY ./scripts/clear-cache.sh /usr/local/bin/
COPY ./scripts/warm-cache.sh /usr/local/bin/
COPY ./scripts/sync-cache.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/clear-cache.sh \
    /usr/local/bin/warm-cache.sh \
    /usr/local/bin/sync-cache.sh

# Set up environment variables for the main dev container to use
ENV NUGET_PACKAGES=/cache/dotnet/nuget \
    DOTNET_CLI_HOME=/cache/dotnet \
    PYTHONUSERBASE=/cache/python \
    PIP_CACHE_DIR=/cache/python/pip \
    UV_CACHE_DIR=/cache/python/uv \
    npm_config_cache=/cache/npm

# Set health check to ensure the service is ready
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/bin/sh", "-c", "ls /cache > /dev/null"]

# Run forever
CMD ["sh", "-c", "echo 'Build cache sidecar container is running'; while true; do sleep 3600; done"]
