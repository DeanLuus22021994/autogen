# Dockerfile for instant markdown linting rule testing
# Uses CircleCI recommended practices for fast startup times

# Use a minimal Node.js image as base
FROM node:18-alpine

# Set labels for better container management
LABEL maintainer="AutoGen Team"
LABEL description="Fast startup container for markdown linting rule testing"
LABEL org.opencontainers.image.source="https://github.com/microsoft/autogen"

# Set working directory
WORKDIR /app

# Install markdownlint-cli2 and dependencies
# Use a separate layer for npm dependencies to leverage Docker cache
RUN npm init -y && \
    npm install --no-fund --no-audit markdownlint-cli2@0.7.1 && \
    # Add any other markdown linting dependencies here
    npm cache clean --force && \
    # Create cache directory to avoid potential permissions issues
    mkdir -p /app/.npm-cache && \
    chmod -R 777 /app/.npm-cache

# Set npm cache directory to reduce build time and permission issues
ENV npm_config_cache=/app/.npm-cache

# Trick to improve startup time (CircleCI recommendation)
# Pre-warm the Node.js runtime
RUN node -e "console.log('Node.js runtime pre-warmed')"

# Create directories for mounting
RUN mkdir -p /app/test /app/rules /app/config && \
    chmod -R 777 /app/test /app/rules /app/config

# Enable shell script execution
COPY ./run-tests.sh /app/
RUN chmod +x /app/run-tests.sh

# Set entrypoint to the test runner script
ENTRYPOINT ["/app/run-tests.sh"]

# Default command just shows help if no arguments are provided
CMD ["--help"]
