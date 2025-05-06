# Setup-EnhancedDevContainer.ps1
# Sets up the enhanced DevContainer configuration for AutoGen

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$Force = $false
)

$ErrorActionPreference = 'Stop'
$GREEN = [ConsoleColor]::Green
$YELLOW = [ConsoleColor]::Yellow
$RED = [ConsoleColor]::Red
$CYAN = [ConsoleColor]::Cyan
$WHITE = [ConsoleColor]::White

Write-Host "🚀 AutoGen Enhanced DevContainer Setup" -ForegroundColor $CYAN

# Check Docker installation
try {
    $dockerVersion = docker --version
    if ($dockerVersion -match 'version (\d+\.\d+\.\d+)') {
        $version = $matches[1]
        Write-Host "✅ Found Docker version: $version" -ForegroundColor $GREEN

        # Check if version meets requirements
        $dockerVersionObj = [Version]$version
        $requiredVersionObj = [Version]"4.40.0"

        if ($dockerVersionObj -lt $requiredVersionObj) {
            Write-Host "❌ Docker version is less than 4.40.0" -ForegroundColor $RED
            Write-Host "   Docker Model Runner requires Docker Desktop 4.40+." -ForegroundColor $RED
            Write-Host "   Please upgrade Docker Desktop to use Docker Model Runner." -ForegroundColor $RED
            exit 1
        }
    } else {
        Write-Host "⚠️ Could not determine Docker version." -ForegroundColor $YELLOW
    }
} catch {
    Write-Host "❌ Docker is not installed or not in PATH." -ForegroundColor $RED
    Write-Host "   Please install Docker Desktop 4.40+ before continuing." -ForegroundColor $RED
    exit 1
}

# Check for VS Code Dev Containers extension
Write-Host "`n🔍 Checking for VS Code Dev Containers extension..." -ForegroundColor $CYAN
$vsCodeExtensions = code --list-extensions
if ($vsCodeExtensions -contains "ms-vscode-remote.remote-containers") {
    Write-Host "✅ VS Code Dev Containers extension is installed." -ForegroundColor $GREEN
} else {
    Write-Host "⚠️ VS Code Dev Containers extension not found." -ForegroundColor $YELLOW
    Write-Host "   Installing Dev Containers extension..." -ForegroundColor $YELLOW
    code --install-extension ms-vscode-remote.remote-containers
    Write-Host "✅ Dev Containers extension installed." -ForegroundColor $GREEN
}

# Create or update the DevContainer configuration files
$repoRoot = $PSScriptRoot
$devContainerDir = Join-Path $repoRoot ".devcontainer"

# Enhanced DevContainer configuration file
$enhancedDevContainerPath = Join-Path $devContainerDir "enhanced-devcontainer.json"
$devContainerContent = Get-Content -Path $enhancedDevContainerPath -Raw -ErrorAction SilentlyContinue

if (-not $devContainerContent -or $Force) {
    Write-Host "`n🔧 Creating enhanced DevContainer configuration file..." -ForegroundColor $CYAN

    # Contents of enhanced-devcontainer.json are defined here
    $devContainerJson = @'
{
    "name": "AutoGen Enhanced DevContainer",
    "dockerComposeFile": "enhanced-docker-compose.yml",
    "service": "devcontainer",
    "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",

    "remoteEnv": {
        "LOCAL_WORKSPACE_FOLDER": "${localEnv:LOCAL_WORKSPACE_FOLDER}",
        "FORK_AUTOGEN_OWNER": "${localEnv:FORK_AUTOGEN_OWNER}",
        "FORK_AUTOGEN_SSH_REPO_URL": "${localEnv:FORK_AUTOGEN_SSH_REPO_URL}",
        "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN": "${localEnv:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}",
        "FORK_AUTOGEN_USER_DOCKER_USERNAME": "${localEnv:FORK_AUTOGEN_USER_DOCKER_USERNAME}",
        "FORK_USER_DOCKER_ACCESS_TOKEN": "${localEnv:FORK_USER_DOCKER_ACCESS_TOKEN}",
        "FORK_HUGGINGFACE_ACCESS_TOKEN": "${localEnv:FORK_HUGGINGFACE_ACCESS_TOKEN}"
    },

    "features": {
        "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {
            "moby": true,
            "installDockerBuildx": true,
            "version": "latest",
            "dockerDashComposeVersion": "none"
        },
        "ghcr.io/devcontainers/features/git:1": {}
    },

    "postCreateCommand": "bash .devcontainer/enhanced-startup.sh",

    "remoteUser": "root",

    "customizations": {
        "vscode": {
            "extensions": [
                "ms-python.python",
                "ms-python.debugpy",
                "GitHub.copilot",
                "ms-dotnettools.csdevkit",
                "ms-dotnettools.vscodeintellicode-csharp",
                "github.vscode-github-actions",
                "ms-azuretools.vscode-docker"
            ],
            "settings": {
                "python.defaultInterpreterPath": "/workspaces/autogen/python/.venv/bin/python",
                "python.linting.enabled": true,
                "python.linting.pylintEnabled": true,
                "dotnet.preferCSharpExtension": true,
                "editor.formatOnSave": true,
                "editor.rulers": [101],
                "files.insertFinalNewline": true,
                "files.trimTrailingWhitespace": true
            }
        }
    },

    "shutdownAction": "none",

    "waitFor": "onCreateCommand",

    "portsAttributes": {
        "5000": {
            "label": "Web App",
            "onAutoForward": "notify"
        }
    }
}
'@
    Set-Content -Path $enhancedDevContainerPath -Value $devContainerJson
    Write-Host "✅ Created enhanced DevContainer configuration file at: $enhancedDevContainerPath" -ForegroundColor $GREEN
} else {
    Write-Host "✅ Enhanced DevContainer configuration file already exists at: $enhancedDevContainerPath" -ForegroundColor $GREEN
}

# Enhanced Docker Compose file
$dockerComposePath = Join-Path $devContainerDir "enhanced-docker-compose.yml"
$dockerComposeContent = Get-Content -Path $dockerComposePath -Raw -ErrorAction SilentlyContinue

if (-not $dockerComposeContent -or $Force) {
    Write-Host "`n🔧 Creating enhanced Docker Compose file..." -ForegroundColor $CYAN

    # Contents of enhanced-docker-compose.yml are defined here
    $dockerComposeYml = @'
version: '3.8'

services:
  devcontainer:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        VARIANT: "3.10"
    volumes:
      - ..:/workspaces/autogen:cached
      - /var/run/docker.sock:/var/run/docker.sock
      - python-packages:/workspaces/autogen/python/.venv
      - dotnet-packages:/workspaces/autogen/dotnet/artifacts
      - model-cache:/opt/autogen/models
    environment:
      - MODEL_RUNNER_ENDPOINT=http://model-runner.docker.internal/engines/v1/chat/completions
      - MODEL_RUNNER_MODELS_ENDPOINT=http://model-runner.docker.internal/engines

    # DevContainer features - keep container running
    command: sleep infinity
    user: root

    # Add extra host for Docker Model Runner
    extra_hosts:
      - "model-runner.docker.internal:host-gateway"

    # Resource limits - adjust as needed
    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 1G

volumes:
  python-packages:
    name: autogen-python-packages
  dotnet-packages:
    name: autogen-dotnet-packages
  model-cache:
    name: autogen-model-cache
'@
    Set-Content -Path $dockerComposePath -Value $dockerComposeYml
    Write-Host "✅ Created enhanced Docker Compose file at: $dockerComposePath" -ForegroundColor $GREEN
} else {
    Write-Host "✅ Enhanced Docker Compose file already exists at: $dockerComposePath" -ForegroundColor $GREEN
}

# Enhanced Startup Script
$startupScriptPath = Join-Path $devContainerDir "enhanced-startup.sh"
$startupScriptContent = Get-Content -Path $startupScriptPath -Raw -ErrorAction SilentlyContinue

if (-not $startupScriptContent -or $Force) {
    Write-Host "`n🔧 Creating enhanced startup script..." -ForegroundColor $CYAN

    # Contents of enhanced-startup.sh are defined here
    $startupScript = @'
#!/bin/bash
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
'@
    Set-Content -Path $startupScriptPath -Value $startupScript -NoNewline
    Write-Host "✅ Created enhanced startup script at: $startupScriptPath" -ForegroundColor $GREEN
} else {
    Write-Host "✅ Enhanced startup script already exists at: $startupScriptPath" -ForegroundColor $GREEN
}

# Ensure the startup script is executable
if (-not (Test-IsWSL)) {
    Write-Host "`n🔧 Converting startup script line endings to LF..." -ForegroundColor $CYAN
    $contentWithLf = (Get-Content $startupScriptPath -Raw).Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText($startupScriptPath, $contentWithLf)
    Write-Host "✅ Converted startup script line endings." -ForegroundColor $GREEN
}

# Create/update ENHANCED-CONTAINER.md
$enhancedContainerDocPath = Join-Path $devContainerDir "ENHANCED-CONTAINER.md"
$enhancedContainerDocContent = Get-Content -Path $enhancedContainerDocPath -Raw -ErrorAction SilentlyContinue

if (-not $enhancedContainerDocContent -or $Force) {
    Write-Host "`n🔧 Creating enhanced container documentation..." -ForegroundColor $CYAN

    # Contents of ENHANCED-CONTAINER.md are defined here
    $enhancedContainerDoc = @'
# Enhanced DevContainer for AutoGen with Docker Model Runner Integration

This document outlines the setup for a permanent DevContainer with Docker Model Runner integration, leveraging volumes for fast code access and development.

## Features

- Persistent container with precompiled dev team code stored in volumes
- Docker Model Runner integration with local AI models
- Low-footprint container (GPU passthrough, no toolkit installation)
- DIR.TAG tracking system integration
- Optimized for agile sprint development

## Prerequisites

- Docker Desktop 4.40+
- Docker Model Runner enabled in Docker Desktop settings
- VS Code with Dev Containers extension installed
- Git with credentials configured

## Setup Instructions

1. Enable Docker Model Runner in Docker Desktop settings
2. Clone the repository and open in VS Code
3. Run the DevContainer setup script
4. Verify the Docker Model Runner integration

## Components

### 1. DevContainer Configuration
- Enhanced Dockerfile with optimization settings
- Docker Compose with persistent volumes
- Integration with Docker Model Runner

### 2. Volume Configuration
- Dedicated volumes for:
  - Python packages (precompiled)
  - .NET build artifacts (precompiled)
  - Docker Model Runner models

### 3. DIR.TAG Integration
- Automated tracking of directory status
- XML configuration for automation tools

### 4. Scripts
- Container initialization
- Volume management
- Model Runner setup

## Docker Model Runner Integration

The following Docker images are available via Docker Model Runner:
- ai/mistral
- ai/mistral-nemo
- ai/mxbai-embed-large
- ai/smollm2

## Usage Notes

- Use the precompiled code for faster development cycles
- Docker Model Runner is accessible via the client in `autogen_extensions/docker`
- DIR.TAG files track the status of directories and development tasks
'@
    Set-Content -Path $enhancedContainerDocPath -Value $enhancedContainerDoc
    Write-Host "✅ Created enhanced container documentation at: $enhancedContainerDocPath" -ForegroundColor $GREEN
} else {
    Write-Host "✅ Enhanced container documentation already exists at: $enhancedContainerDocPath" -ForegroundColor $GREEN
}

# Create DIR.TAG file to track status
$dirTagPath = Join-Path $devContainerDir "DIR.TAG"
$dirTagContent = Get-Content -Path $dirTagPath -Raw -ErrorAction SilentlyContinue

if (-not $dirTagContent -or $Force) {
    Write-Host "`n🔧 Creating DIR.TAG file for DevContainer..." -ForegroundColor $CYAN

    # Get current timestamp in ISO 8601 format
    $timestamp = Get-Date -Format "o"

    # Contents of DIR.TAG are defined here
    $dirTagContent = @"
#INDEX: .devcontainer
#TODO:
  - Configure Docker Model Runner integration with VS Code DONE
  - Set up persistent volumes for code development DONE
  - Implement startup script for environment configuration DONE
  - Create documentation for enhanced container setup DONE
status: DONE
updated: $timestamp
description: |
  Enhanced DevContainer configuration with Docker Model Runner integration,
  persistent volumes for fast development, and optimized setup for agile
  sprint development cycles.
"@
    Set-Content -Path $dirTagPath -Value $dirTagContent
    Write-Host "✅ Created DIR.TAG file at: $dirTagPath" -ForegroundColor $GREEN
} else {
    Write-Host "✅ DIR.TAG file already exists at: $dirTagPath" -ForegroundColor $GREEN
}

# Create/update the tasks.json file to register the enhanced DevContainer tasks
$vsCodeDir = Join-Path $repoRoot ".vscode"
if (-not (Test-Path $vsCodeDir)) {
    New-Item -ItemType Directory -Path $vsCodeDir | Out-Null
}

$tasksJsonPath = Join-Path $vsCodeDir "tasks.json"
$tasksJson = Get-Content -Path $tasksJsonPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue

# If tasks.json doesn't exist or doesn't parse as JSON, create a new one
if (-not $tasksJson) {
    $tasksJson = @{
        version = "2.0.0"
        tasks = @()
    }
}

# Check if the Enhanced DevContainer task already exists
$enhancedDevContainerTask = $tasksJson.tasks | Where-Object { $_.label -eq "Setup Enhanced DevContainer" }
if (-not $enhancedDevContainerTask) {
    $newTask = @{
        label = "Setup Enhanced DevContainer"
        type = "shell"
        command = "pwsh"
        args = @(
            "-File",
            "${workspaceFolder}\\Setup-EnhancedDevContainer.ps1"
        )
        presentation = @{
            reveal = "always"
            panel = "new"
            focus = $true
        }
        group = @{
            kind = "build"
            isDefault = $false
        }
    }
    $tasksJson.tasks += $newTask

    # Convert back to JSON and save
    $tasksJsonContent = $tasksJson | ConvertTo-Json -Depth 10
    Set-Content -Path $tasksJsonPath -Value $tasksJsonContent
    Write-Host "✅ Added Setup Enhanced DevContainer task to tasks.json" -ForegroundColor $GREEN
} else {
    Write-Host "✅ Setup Enhanced DevContainer task already exists in tasks.json" -ForegroundColor $GREEN
}

# Check if the Docker Model Runner task already exists
$dockerModelRunnerTask = $tasksJson.tasks | Where-Object { $_.label -eq "Setup Docker Model Runner" }
if (-not $dockerModelRunnerTask) {
    $newTask = @{
        label = "Setup Docker Model Runner"
        type = "shell"
        command = "pwsh"
        args = @(
            "-File",
            "${workspaceFolder}\\Setup-DockerModelRunner.ps1"
        )
        presentation = @{
            reveal = "always"
            panel = "new"
            focus = $true
        }
        group = @{
            kind = "build"
            isDefault = $false
        }
    }
    $tasksJson.tasks += $newTask

    # Convert back to JSON and save
    $tasksJsonContent = $tasksJson | ConvertTo-Json -Depth 10
    Set-Content -Path $tasksJsonPath -Value $tasksJsonContent
    Write-Host "✅ Added Setup Docker Model Runner task to tasks.json" -ForegroundColor $GREEN
} else {
    Write-Host "✅ Setup Docker Model Runner task already exists in tasks.json" -ForegroundColor $GREEN
}

# SUCCESS!
Write-Host "`n✅ Enhanced DevContainer setup completed successfully!" -ForegroundColor $GREEN
Write-Host "   To use the enhanced DevContainer:" -ForegroundColor $GREEN
Write-Host "   1. Open VS Code command palette (Ctrl+Shift+P)" -ForegroundColor $WHITE
Write-Host "   2. Run 'Dev Containers: Rebuild and Reopen in Container'" -ForegroundColor $WHITE
Write-Host "   3. Once in the container, run 'docker model pull ai/mistral' to pull the Mistral model" -ForegroundColor $WHITE
Write-Host "`n   For more information, see:" -ForegroundColor $CYAN
Write-Host "   .devcontainer/ENHANCED-CONTAINER.md" -ForegroundColor $WHITE

# Helper function to test if running in WSL
function Test-IsWSL {
    return (Test-Path /proc/version) -and (Get-Content /proc/version).Contains("Microsoft")
}
