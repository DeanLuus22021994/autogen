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

# Enhanced DevContainer initialization script

set -e

echo "🚀 Starting enhanced DevContainer initialization..."

# Function to display status messages
status() {
    echo "🔵 $1"
}

# Function to display success messages
success() {
    echo "✅ $1"
}

# Function to display error messages
error() {
    echo "❌ $1"
    exit 1
}

# Check Docker Model Runner access
status "Checking Docker Model Runner access..."
if curl -s --head --fail "http://model-runner.docker.internal/engines" > /dev/null; then
    success "Docker Model Runner is accessible"
else
    echo "⚠️ Docker Model Runner is not accessible. Some features may not work."
    echo "   Please ensure Docker Desktop is running with Model Runner enabled."
fi

# Set up Python environment
status "Setting up Python environment..."
if [ -d "/workspaces/autogen/python/.venv" ]; then
    status "Python virtual environment exists, checking packages..."
    # Activate the virtual environment
    source /workspaces/autogen/python/.venv/bin/activate
    # Install/update packages
    cd /workspaces/autogen
    pip install -e ./python/packages/autogen-core
    pip install -e ./python/packages/autogen-agentchat
    pip install -e ./python/packages/autogen-ext[openai]
    success "Python packages updated"
else
    status "Creating new Python virtual environment..."
    cd /workspaces/autogen
    python -m venv python/.venv
    source /workspaces/autogen/python/.venv/bin/activate
    pip install --upgrade pip
    pip install -e ./python/packages/autogen-core
    pip install -e ./python/packages/autogen-agentchat
    pip install -e ./python/packages/autogen-ext[openai]
    pip install -e ./python/packages/autogen-studio
    success "Python environment created and packages installed"
fi

# Set up .NET environment
status "Setting up .NET environment..."
if [ -d "/workspaces/autogen/dotnet/artifacts" ]; then
    status ".NET artifacts exist, rebuilding solution..."
else
    status "Creating .NET artifacts directory..."
    mkdir -p /workspaces/autogen/dotnet/artifacts
fi

cd /workspaces/autogen/dotnet
dotnet build -c Debug
success ".NET solution built"

# Verify Docker Model Runner integration
status "Verifying Docker Model Runner extension..."
if [ -d "/workspaces/autogen/autogen_extensions/docker" ]; then
    success "Docker Model Runner extension found"
else
    echo "⚠️ Docker Model Runner extension not found at /workspaces/autogen/autogen_extensions/docker"
    echo "   This might affect Docker Model Runner functionality."
fi

# Create symlinks for quick access
status "Creating symlinks for quick access..."
ln -sf /workspaces/autogen/.devcontainer/ENHANCED-CONTAINER.md /workspaces/autogen/CONTAINER-HELP.md
success "Quick access symlinks created"

# Display container information
echo ""
echo "🚀 Enhanced DevContainer setup complete!"
echo "📋 Available Docker Model Runner models:"
curl -s "http://model-runner.docker.internal/engines" | python -m json.tool || echo "  No models available. Run 'docker model pull ai/mistral' to get started."
echo ""
echo "📋 Container specifications:"
echo "  • OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
echo "  • Python: $(python --version)"
echo "  • .NET: $(dotnet --version)"
echo "  • Docker: $(docker --version)"
echo ""
echo "📋 Volume mounts:"
echo "  • Python packages: /workspaces/autogen/python/.venv"
echo "  • .NET packages: /workspaces/autogen/dotnet/artifacts"
echo "  • Model cache: /opt/autogen/models"
echo ""
echo "📋 Documentation:"
echo "  • Enhanced DevContainer: /workspaces/autogen/.devcontainer/ENHANCED-CONTAINER.md"
echo "  • Docker Model Runner: /workspaces/autogen/autogen_extensions/docker/README.md"
echo ""
