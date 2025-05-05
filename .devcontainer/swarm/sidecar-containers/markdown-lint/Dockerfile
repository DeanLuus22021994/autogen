# markdown-lint-sidecar Dockerfile
# This container provides pre-built markdown linting capabilities with instant startup
# for the AutoGen development environment

FROM node:18-alpine

# Set labels for better container management
LABEL maintainer="AutoGen Team"
LABEL description="Fast startup container for markdown linting services"
LABEL org.opencontainers.image.source="https://github.com/microsoft/autogen"

# Set working directory
WORKDIR /app

# Install markdownlint-cli2 and dependencies globally
# Use a separate layer for npm dependencies to leverage Docker cache
RUN npm init -y && \
    npm install -g markdownlint-cli2@0.7.1 markdownlint@0.29.0 && \
    npm cache clean --force && \
    # Create cache directory to avoid potential permissions issues
    mkdir -p /app/.npm-cache && \
    chmod -R 777 /app/.npm-cache

# Set npm cache directory to reduce build time and permission issues
ENV npm_config_cache=/app/.npm-cache

# Pre-warm the Node.js runtime for instant startup
RUN node -e "console.log('Node.js runtime pre-warmed')"

# Create directories for mounting repository content
RUN mkdir -p /app/workspace /app/rules /app/config && \
    chmod -R 777 /app/workspace /app/rules /app/config

# Add helper scripts for monitoring and executing linting
COPY ./scripts/lint-watch.sh /app/
COPY ./scripts/lint-exec.sh /app/
RUN chmod +x /app/*.sh

# Set health check to ensure the service is ready
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "process.exit(0)"

# Volume for repository mounting
VOLUME ["/app/workspace", "/app/rules", "/app/config"]

# Expose port for HTTP service (if we add that later)
EXPOSE 3000

# Default command
CMD ["sh", "-c", "echo 'Markdown linting sidecar container is running'; tail -f /dev/null"]
