# Initialize-MistralGPURunner.ps1
<#
.SYNOPSIS
    Sets up a highly optimized Mistral NeMo model on NVIDIA GPUs using Docker Model Runner.

.DESCRIPTION
    This script initializes Docker Swarm, configures GPU support, pulls the required Mistral NeMo model
    from Docker Model Runner, and deploys it as a Swarm service optimized for high-performance inference.

.PARAMETER StackName
    Optional. The name of the stack to deploy. Default is "autogen-mistral".

.PARAMETER ModelType
    Optional. The specific Mistral model to use. Default is "ai/mistral-nemo".

.PARAMETER GPUCount
    Optional. The number of GPUs to allocate. Default is 1.

.PARAMETER Quantization
    Optional. The quantization level to use. Default is "int8". Options: "none", "int8", "int4".

.PARAMETER ContextLength
    Optional. The context length for the model. Default is 8192.

.EXAMPLE
    .\Initialize-MistralGPURunner.ps1

.EXAMPLE
    .\Initialize-MistralGPURunner.ps1 -StackName custom-mistral -ModelType ai/mistral-nemo -GPUCount 2 -Quantization int4 -ContextLength 16384
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$StackName = "autogen-mistral",

    [Parameter(Mandatory = $false)]
    [ValidateSet("ai/mistral", "ai/mistral-nemo")]
    [string]$ModelType = "ai/mistral-nemo",

    [Parameter(Mandatory = $false)]
    [int]$GPUCount = 1,

    [Parameter(Mandatory = $false)]
    [ValidateSet("none", "int8", "int4")]
    [string]$Quantization = "int8",

    [Parameter(Mandatory = $false)]
    [int]$ContextLength = 8192
)

$ErrorActionPreference = 'Stop'
$GREEN = [ConsoleColor]::Green
$YELLOW = [ConsoleColor]::Yellow
$RED = [ConsoleColor]::Red
$CYAN = [ConsoleColor]::Cyan
$WHITE = [ConsoleColor]::White

Write-Host "🚀 Initializing Mistral GPU Runner" -ForegroundColor $CYAN
Write-Host "===============================" -ForegroundColor $CYAN
Write-Host "Stack Name: $StackName" -ForegroundColor $WHITE
Write-Host "Model Type: $ModelType" -ForegroundColor $WHITE
Write-Host "GPU Count: $GPUCount" -ForegroundColor $WHITE
Write-Host "Quantization: $Quantization" -ForegroundColor $WHITE
Write-Host "Context Length: $ContextLength" -ForegroundColor $WHITE
Write-Host "===============================" -ForegroundColor $CYAN

# Check Docker installation and version
Write-Host "`n🔍 Checking Docker installation..." -ForegroundColor $CYAN
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

# Check if Docker Swarm is initialized
Write-Host "`n🔍 Checking Docker Swarm status..." -ForegroundColor $CYAN
$swarmStatus = docker info --format '{{.Swarm.LocalNodeState}}'

if ($swarmStatus -ne "active") {
    Write-Host "🔄 Initializing Docker Swarm..." -ForegroundColor $YELLOW
    $initCommand = "docker swarm init"
    Invoke-Expression $initCommand

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to initialize Docker Swarm." -ForegroundColor $RED
        exit 1
    }

    Write-Host "✅ Docker Swarm initialized successfully." -ForegroundColor $GREEN
} else {
    Write-Host "✅ Docker Swarm is already active." -ForegroundColor $GREEN
}

# Configure GPU support
Write-Host "`n🔍 Checking NVIDIA GPU support..." -ForegroundColor $CYAN
try {
    $gpuCheck = docker run --rm --gpus all nvidia/cuda:12.0.1-base-ubuntu22.04 nvidia-smi
    Write-Host "✅ NVIDIA GPU support is configured correctly." -ForegroundColor $GREEN
} catch {
    Write-Host "⚠️ NVIDIA GPU support is not properly configured." -ForegroundColor $YELLOW
    Write-Host "   Setting up GPU support for Docker..." -ForegroundColor $YELLOW

    # Configure Docker daemon for NVIDIA GPU support
    $daemonConfigPath = if ($IsWindows) { "$env:ProgramData\Docker\config\daemon.json" } else { "/etc/docker/daemon.json" }

    if (Test-Path $daemonConfigPath) {
        $daemonConfig = Get-Content -Path $daemonConfigPath -Raw | ConvertFrom-Json
    } else {
        $daemonConfig = [PSCustomObject]@{}
    }

    # Add NVIDIA runtime if not present
    $modified = $false

    if (-not ($daemonConfig.PSObject.Properties.Name -contains "runtimes")) {
        Add-Member -InputObject $daemonConfig -MemberType NoteProperty -Name "runtimes" -Value @{}
        $modified = $true
    }

    if (-not ($daemonConfig.runtimes.PSObject.Properties.Name -contains "nvidia")) {
        $daemonConfig.runtimes | Add-Member -MemberType NoteProperty -Name "nvidia" -Value @{
            "path" = if ($IsWindows) { "nvidia-container-runtime" } else { "/usr/bin/nvidia-container-runtime" }
        }
        $modified = $true
    }

    # Save changes if any were made
    if ($modified) {
        if (-not (Test-Path (Split-Path $daemonConfigPath -Parent))) {
            New-Item -Path (Split-Path $daemonConfigPath -Parent) -ItemType Directory -Force | Out-Null
        }

        $daemonConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $daemonConfigPath
        Write-Host "✅ Docker daemon configured for NVIDIA GPU support." -ForegroundColor $GREEN
        Write-Host "⚠️ Please restart Docker for the changes to take effect." -ForegroundColor $YELLOW
        Write-Host "   After restarting Docker, run this script again." -ForegroundColor $YELLOW
        exit 0
    }
}

# Check Docker Model Runner
Write-Host "`n🔍 Checking Docker Model Runner..." -ForegroundColor $CYAN
try {
    # Try to access the model runner endpoint
    $modelRunnerEndpoint = "http://model-runner.docker.internal/engines"
    $response = Invoke-WebRequest -Uri $modelRunnerEndpoint -UseBasicParsing -ErrorAction SilentlyContinue

    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Docker Model Runner is available and responding!" -ForegroundColor $GREEN

        # Parse the JSON response to get available models
        $availableModels = $response.Content | ConvertFrom-Json

        # Check if our required model is available
        if ($availableModels -contains $ModelType) {
            Write-Host "✅ Required model '$ModelType' is available." -ForegroundColor $GREEN
        } else {
            Write-Host "🔄 Required model '$ModelType' is not available. Pulling model..." -ForegroundColor $YELLOW
            docker model pull $ModelType

            if ($LASTEXITCODE -ne 0) {
                Write-Host "❌ Failed to pull model '$ModelType'." -ForegroundColor $RED
                exit 1
            }

            Write-Host "✅ Model '$ModelType' pulled successfully." -ForegroundColor $GREEN
        }
    }
} catch {
    Write-Host "❌ Docker Model Runner endpoint is not accessible." -ForegroundColor $RED
    Write-Host "   Please ensure Docker Desktop is running with Model Runner enabled:" -ForegroundColor $RED
    Write-Host "   1. Open Docker Desktop" -ForegroundColor $WHITE
    Write-Host "   2. Go to Settings > Features in development > Beta" -ForegroundColor $WHITE
    Write-Host "   3. Enable 'Docker Model Runner'" -ForegroundColor $WHITE
    Write-Host "   4. Click 'Apply & restart'" -ForegroundColor $WHITE
    exit 1
}

# Label current node for GPU
Write-Host "`n🔍 Configuring node labels for GPU..." -ForegroundColor $CYAN
$nodeID = docker node ls --filter "role=manager" --format "{{.ID}}"
docker node update --label-add gpu=true $nodeID
Write-Host "✅ Node labeled for GPU allocation." -ForegroundColor $GREEN

# Create config file for deployment
Write-Host "`n🔍 Preparing deployment configuration..." -ForegroundColor $CYAN
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configDir = Join-Path $scriptDir ".." "configs"
$configPath = Join-Path $configDir "mistral-gpu.config.json"

if (Test-Path $configPath) {
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    # Update config with parameters
    $config.stackName = $StackName
    $config.environment.MISTRAL_IMAGE = $ModelType
    $config.environment.GPU_COUNT = $GPUCount.ToString()
    $config.environment.QUANTIZATION = $Quantization
    $config.environment.CONTEXT_LENGTH = $ContextLength.ToString()

    # Save updated config
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
    Write-Host "✅ Deployment configuration updated." -ForegroundColor $GREEN
} else {
    Write-Host "❌ Configuration file not found: $configPath" -ForegroundColor $RED
    exit 1
}

# Deploy the stack
Write-Host "`n🚀 Deploying Mistral GPU stack..." -ForegroundColor $CYAN
$deployScriptPath = Join-Path $scriptDir "Deploy-SwarmStack.ps1"
$deployCommand = "& '$deployScriptPath' -ConfigFile '$configPath' -StackName '$StackName'"
Invoke-Expression $deployCommand

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy Mistral GPU stack." -ForegroundColor $RED
    exit 1
}

# SUCCESS!
Write-Host "`n✅ Mistral GPU stack deployed successfully!" -ForegroundColor $GREEN
Write-Host "   StackName: $StackName" -ForegroundColor $WHITE
Write-Host "   Model: $ModelType" -ForegroundColor $WHITE
Write-Host "   Check the status of your deployment with:" -ForegroundColor $CYAN
Write-Host "   docker service ls --filter 'name=$StackName'" -ForegroundColor $WHITE
Write-Host "`n   To access the model, use the endpoint:" -ForegroundColor $CYAN
Write-Host "   http://localhost:8080/v1/chat/completions" -ForegroundColor $WHITE
