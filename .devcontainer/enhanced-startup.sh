#!/bin/bash
# Enhanced startup script for AutoGen DevContainer with Docker Model Runner support

set -e

echo "🚀 Starting Enhanced AutoGen DevContainer Setup..."

# Log start time for performance tracking
START_TIME=$(date +%s)

# Setup Git configuration for repository access
echo "📂 Setting up Git configuration..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/prepare-git.sh" ]; then
    chmod +x "$SCRIPT_DIR/prepare-git.sh"
    "$SCRIPT_DIR/prepare-git.sh"
fi

# Create symbolic links to precompiled artifacts
echo "🔗 Setting up links to persistent volumes..."
PYTHON_PACKAGES_DIR="/workspaces/autogen/python/packages"
DOTNET_ARTIFACTS_DIR="/workspaces/autogen/dotnet/artifacts"

# Create symbolic links if directories exist
if [ -d "$PRECOMPILED_PACKAGES_PATH" ] && [ -d "$PYTHON_PACKAGES_DIR" ]; then
    echo "  ├─ Linking Python packages..."
    # For each package in the source, create a link to the precompiled version
    find "$PYTHON_PACKAGES_DIR" -maxdepth 1 -type d -not -path "$PYTHON_PACKAGES_DIR" | while read pkg; do
        PKG_NAME=$(basename "$pkg")
        PRECOMPILED_PKG="$PRECOMPILED_PACKAGES_PATH/$PKG_NAME"
        if [ -d "$PRECOMPILED_PKG" ]; then
            ln -sf "$PRECOMPILED_PKG" "$PYTHON_PACKAGES_DIR/$PKG_NAME.precompiled"
            echo "  │  ├─ Linked $PKG_NAME"
        fi
    done
fi

if [ -d "$DOTNET_ARTIFACTS_PATH" ] && [ -d "$DOTNET_ARTIFACTS_DIR" ]; then
    echo "  └─ Linking .NET artifacts..."
    # Create symlinks for .NET artifacts
    ln -sf "$DOTNET_ARTIFACTS_PATH" "$DOTNET_ARTIFACTS_DIR/precompiled"
fi

# Setup Docker Model Runner integration
echo "🐳 Verifying Docker Model Runner..."
if /usr/local/bin/verify-model-runner.sh; then
    echo "  └─ Docker Model Runner is available and configured correctly"
else
    echo "  ⚠️ Docker Model Runner is not available or not configured correctly"
    echo "  ├─ Please ensure Docker Desktop 4.40+ is installed"
    echo "  └─ Enable Docker Model Runner in Docker Desktop settings"
fi

# Setup .NET
echo "🔧 Setting up .NET environment..."
dotnet workload update
dotnet dev-certs https --trust

# Setup Python
echo "🐍 Setting up Python environment..."
cd /workspaces/autogen/python
if [ ! -d ".venv" ]; then
    echo "  ├─ Creating new Python virtual environment..."
    python -m venv .venv
fi
source .venv/bin/activate
pip install -q uv
echo "  ├─ Synchronizing Python packages..."
uv sync
echo "  └─ Python environment ready"

# Update PATH in user profile
echo "export PATH=$PATH" >> ~/.bashrc

# Check for DIR.TAG support
echo "📋 Setting up DIR.TAG system..."
DIR_TAG_SCRIPT="/workspaces/autogen/.devcontainer/manage-dir-tags.sh"
if [ -f "$DIR_TAG_SCRIPT" ]; then
    chmod +x "$DIR_TAG_SCRIPT"
    "$DIR_TAG_SCRIPT" --action check --verbose
else
    echo "  └─ DIR.TAG management script not found, skipping"
fi

# Setup Docker credentials if available
if [ -n "$FORK_USER_DOCKER_ACCESS_TOKEN" ] && [ -n "$FORK_AUTOGEN_USER_DOCKER_USERNAME" ]; then
    echo "🔐 Setting up Docker credentials..."
    echo "$FORK_USER_DOCKER_ACCESS_TOKEN" | docker login --username "$FORK_AUTOGEN_USER_DOCKER_USERNAME" --password-stdin
fi

# Calculate and display execution time
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))
echo "✅ Enhanced DevContainer setup completed in ${EXECUTION_TIME} seconds!"
echo "   Container is now ready for development with Docker Model Runner integration."
