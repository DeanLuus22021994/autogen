# Setup-EnhancedDevContainer.ps1
# Sets up the enhanced DevContainer with Docker Model Runner integration

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$SkipDockerModelRunnerCheck = $false,

    [Parameter()]
    [switch]$Force = $false
)

$ErrorActionPreference = 'Stop'

# Script constants
$REQUIRED_DOCKER_VERSION = "4.40.0"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$DEVCONTAINER_DIR = Join-Path $SCRIPT_DIR ".devcontainer"
$ORIGINAL_DEVCONTAINER_JSON = Join-Path $DEVCONTAINER_DIR "devcontainer.json"
$ENHANCED_DEVCONTAINER_JSON = Join-Path $DEVCONTAINER_DIR "enhanced-devcontainer.json"
$BACKUP_SUFFIX = ".original"

Write-Host "🚀 Setting up Enhanced DevContainer with Docker Model Runner Integration" -ForegroundColor Cyan

# Check Docker installation
try {
    $dockerVersion = docker --version
    if ($dockerVersion -match 'version (\d+\.\d+\.\d+)') {
        $version = $matches[1]
        Write-Host "✅ Found Docker version: $version" -ForegroundColor Green

        # Check if version meets requirements
        $dockerVersionObj = [Version]$version
        $requiredVersionObj = [Version]$REQUIRED_DOCKER_VERSION

        if ($dockerVersionObj -lt $requiredVersionObj) {
            Write-Host "⚠️ Docker version is less than $REQUIRED_DOCKER_VERSION" -ForegroundColor Yellow
            Write-Host "   Docker Model Runner requires Docker Desktop 4.40+." -ForegroundColor Yellow
            Write-Host "   Please upgrade Docker Desktop to use Docker Model Runner." -ForegroundColor Yellow

            if (-not $Force) {
                $proceed = Read-Host "Do you want to proceed anyway? (y/n)"
                if ($proceed -ne "y") {
                    Write-Host "❌ Setup aborted." -ForegroundColor Red
                    exit 1
                }
            }
        }
    } else {
        Write-Host "⚠️ Could not determine Docker version." -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Docker is not installed or not in PATH." -ForegroundColor Red
    Write-Host "   Please install Docker Desktop 4.40+ before continuing." -ForegroundColor Red
    exit 1
}

# Check Docker Model Runner if not skipped
if (-not $SkipDockerModelRunnerCheck) {
    Write-Host "🔍 Checking Docker Model Runner configuration..." -ForegroundColor Cyan

    try {
        $modelRunnerEndpoint = "http://model-runner.docker.internal/engines"
        $response = Invoke-WebRequest -Uri $modelRunnerEndpoint -UseBasicParsing -ErrorAction SilentlyContinue

        if ($response.StatusCode -eq 200) {
            Write-Host "✅ Docker Model Runner is available and responding!" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️ Docker Model Runner endpoint is not accessible." -ForegroundColor Yellow
        Write-Host "   Please ensure Docker Desktop is running with Model Runner enabled:" -ForegroundColor Yellow
        Write-Host "   1. Open Docker Desktop" -ForegroundColor White
        Write-Host "   2. Go to Settings > Features in development > Beta" -ForegroundColor White
        Write-Host "   3. Enable 'Docker Model Runner'" -ForegroundColor White
        Write-Host "   4. Click 'Apply & restart'" -ForegroundColor White

        if (-not $Force) {
            $proceed = Read-Host "Do you want to proceed anyway? (y/n)"
            if ($proceed -ne "y") {
                Write-Host "❌ Setup aborted." -ForegroundColor Red
                exit 1
            }
        }
    }
}

# Back up original devcontainer.json if needed
if (Test-Path $ORIGINAL_DEVCONTAINER_JSON) {
    $backupPath = "$ORIGINAL_DEVCONTAINER_JSON$BACKUP_SUFFIX"

    if (-not (Test-Path $backupPath)) {
        Write-Host "📁 Backing up original devcontainer.json..." -ForegroundColor Cyan
        Copy-Item -Path $ORIGINAL_DEVCONTAINER_JSON -Destination $backupPath
        Write-Host "✅ Original devcontainer.json backed up to: $backupPath" -ForegroundColor Green
    }
}

# Replace with enhanced devcontainer.json
Write-Host "📁 Installing enhanced DevContainer configuration..." -ForegroundColor Cyan
if (Test-Path $ENHANCED_DEVCONTAINER_JSON) {
    Copy-Item -Path $ENHANCED_DEVCONTAINER_JSON -Destination $ORIGINAL_DEVCONTAINER_JSON -Force
    Write-Host "✅ Enhanced DevContainer configuration installed!" -ForegroundColor Green
} else {
    Write-Host "❌ Enhanced DevContainer configuration file not found: $ENHANCED_DEVCONTAINER_JSON" -ForegroundColor Red
    exit 1
}

# Install Docker Model Runner enabled VS Code Docker extension
Write-Host "🔌 Checking VS Code Docker extension..." -ForegroundColor Cyan
try {
    $result = code --list-extensions | Select-String -Pattern "ms-azuretools.vscode-docker"
    if ($result) {
        Write-Host "✅ VS Code Docker extension is already installed." -ForegroundColor Green
    } else {
        Write-Host "📥 Installing VS Code Docker extension..." -ForegroundColor Cyan
        code --install-extension ms-azuretools.vscode-docker
        Write-Host "✅ VS Code Docker extension installed successfully." -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️ Could not verify VS Code extensions. Please ensure VS Code is in your PATH." -ForegroundColor Yellow
}

# SUCCESS!
Write-Host "`n✅ Enhanced DevContainer setup completed successfully!" -ForegroundColor Green
Write-Host "   To use the enhanced DevContainer:" -ForegroundColor Cyan
Write-Host "   1. Open VS Code command palette (Ctrl+Shift+P)" -ForegroundColor White
Write-Host "   2. Run 'Dev Containers: Rebuild and Reopen in Container'" -ForegroundColor White
Write-Host "   3. Wait for the container to build and start" -ForegroundColor White
Write-Host "`n   Your enhanced container with Docker Model Runner integration will be ready to use!" -ForegroundColor Green
