# AutoGen Development Sidecar Containers

This directory contains Docker-based sidecar containers designed to accelerate AutoGen development by providing pre-warmed, pre-configured environments for various development tasks.

## Overview

The sidecar containers help optimize the development workflow by:

- Providing instant-start development tools and services
- Caching dependencies to speed up builds
- Offering consistent development environments
- Enabling parallel execution of common tasks

## Available Containers

The following sidecar containers are available:

### 1. Markdown Linting (`markdown-lint`)

Provides real-time markdown linting with instant startup:

- Pre-configured with AutoGen's markdown linting rules
- Watches for changes in markdown files
- Provides both CLI and programmatic access

### 2. Build Cache (`build-cache`)

Maintains a persistent cache for various build dependencies:

- .NET NuGet package cache
- Python pip/uv package cache
- NPM module cache
- Configuration for optimal caching

### 3. Build Tools (`build-tools`)

Pre-warmed build environment with:

- .NET SDK with pre-JIT compilation
- Python with uv/pip optimizations
- Node.js with npm
- Pre-configured build scripts

## Getting Started

### Prerequisites

- Docker and Docker Compose installed
- VS Code with the Remote Containers extension (for VS Code integration)

### Starting the Sidecar Containers

Use the management script to control the containers:

```bash
# Start all sidecar containers
./manage-sidecars.sh start

# Start a specific container
./manage-sidecars.sh start build-tools

# Check status
./manage-sidecars.sh status

# View logs
./manage-sidecars.sh logs markdown-lint
```

### Integration with VS Code

The sidecar containers are automatically integrated with VS Code tasks when using the provided devcontainer. You can trigger them from the Command Palette:

1. Markdown Linting: `Tasks: Run Task > Lint Markdown Files`
2. Build with Cache: `Tasks: Run Task > Build .NET with Cache`
3. Python with Cache: `Tasks: Run Task > Build Python with Cache`

## Environment Variables

Each container supports specific environment variables to customize its behavior:

### Markdown Lint Container

- `WATCH_PATHS`: Comma-separated list of paths to watch for changes (default: `/workspace`)
- `LINT_CONFIG_PATH`: Path to markdownlint config file (default: `/workspace/.github/linting/.markdownlint-cli2.jsonc`)
- `CUSTOM_RULES_PATH`: Path to custom linting rules (default: `/workspace/.github/linting/rules`)

### Build Cache Container

- `CACHE_BASE`: Base path for all caches (default: `/cache`)
- `WORKSPACE_PATH`: Path to the mounted workspace (default: `/workspace`)

### Build Tools Container

- `DOTNET_CLI_HOME`: .NET CLI home directory (default: `/cache/dotnet`)
- `NUGET_PACKAGES`: NuGet packages directory (default: `/cache/dotnet/nuget`)
- `PYTHONUSERBASE`: Python user base directory (default: `/cache/python`)
- `PIP_CACHE_DIR`: Pip cache directory (default: `/cache/python/pip`)
- `UV_CACHE_DIR`: UV cache directory (default: `/cache/python/uv`)
- `npm_config_cache`: NPM cache directory (default: `/cache/npm`)

## Advanced Configuration

### Custom Docker Compose Configuration

For advanced usage, you can create a custom `docker-compose.override.yml` file to override specific settings:

```yaml
version: '3.8'
services:
  build-tools:
    environment:
      - ADDITIONAL_ENV_VAR=value
    volumes:
      - /additional/path:/mount/point
```

### Volume Management

The shared cache volume (`cache-volume`) persists across container restarts and can be managed with the cache scripts:

```bash
# Start a shell in the build-cache container
./manage-sidecars.sh exec build-cache sh

# Then run cache management commands
/app/scripts/clear-cache.sh --all
/app/scripts/warm-cache.sh --all
/app/scripts/sync-cache.sh --source /external/cache --all --to-cache
```

## Troubleshooting

### Container Not Starting

If a container fails to start, check the logs:

```bash
./manage-sidecars.sh logs [container-name]
```

### Cache Issues

If you're experiencing cache-related issues, try clearing the cache:

```bash
./manage-sidecars.sh exec build-cache /app/scripts/clear-cache.sh --all
```

### Performance

For optimal performance, ensure the Docker engine has sufficient resources allocated (CPU, memory, disk).

## Contributing

When modifying the sidecar containers:

1. Update the Dockerfile with proper comments
2. Test with and without cached images
3. Ensure startup time is minimized
4. Document any new environment variables or mount points
