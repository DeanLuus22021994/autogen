# PowerShell script to start smoll2 LLM on RAM disk with GPU acceleration

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$DockerSwarm = $false,

    [Parameter(Mandatory = $false)]
    [string]$RamDiskSize = "8G",

    [Parameter(Mandatory = $false)]
    [ValidateSet("1", "all")]
    [string]$GpuDevices = "all",

    [Parameter(Mandatory = $false)]
    [switch]$ForceRebuild,

    [Parameter(Mandatory = $false)]
    [switch]$SkipRamDiskSetup,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$GREEN = [ConsoleColor]::Green
$YELLOW = [ConsoleColor]::Yellow
$RED = [ConsoleColor]::Red
$CYAN = [ConsoleColor]::Cyan
$WHITE = [ConsoleColor]::White

function Test-CommandExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    return [bool](Get-Command -Name $Command -ErrorAction SilentlyContinue)
}

Write-Host "🚀 Starting smoll2 LLM on RAM disk with GPU acceleration" -ForegroundColor $CYAN

# Check Docker installation
if (-not (Test-CommandExists -Command "docker")) {
    Write-Host "❌ Docker is not installed or not in PATH." -ForegroundColor $RED
    Write-Host "Please install Docker and try again." -ForegroundColor $WHITE
    exit 1
}

# Check for Docker Model Runner compatibility
try {
    $dockerVersion = docker --version
    if ($dockerVersion -match 'version (\d+\.\d+\.\d+)') {
        $version = $matches[1]
        Write-Host "✅ Found Docker version: $version" -ForegroundColor $GREEN

        # Check if version meets requirements for Docker Model Runner
        $dockerVersionObj = [Version]$version
        $requiredVersionObj = [Version]"4.40.0"

        if ($dockerVersionObj -lt $requiredVersionObj) {
            Write-Host "⚠️ Warning: Docker version $version may not support Docker Model Runner." -ForegroundColor $YELLOW
            Write-Host "Docker Model Runner requires Docker Desktop 4.40.0 or higher." -ForegroundColor $WHITE

            $continue = Read-Host "Do you want to continue anyway? (Y/N)"
            if ($continue -ne "Y" -and $continue -ne "y") {
                Write-Host "Operation aborted." -ForegroundColor $YELLOW
                exit 0
            }
        } else {
            Write-Host "✅ Docker version compatible with Docker Model Runner" -ForegroundColor $GREEN
        }
    } else {
        Write-Host "⚠️ Could not parse Docker version." -ForegroundColor $YELLOW
    }
} catch {
    Write-Host "❌ Error checking Docker version: $_" -ForegroundColor $RED
    exit 1
}

# Check for NVIDIA GPU support
$gpuAvailable = $false
try {
    if (Test-CommandExists -Command "nvidia-smi") {
        $gpuInfo = nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>$null
        if ($LASTEXITCODE -eq 0) {
            $gpuAvailable = $true
            Write-Host "✅ NVIDIA GPU detected: $gpuInfo" -ForegroundColor $GREEN
        }
    }

    if (-not $gpuAvailable) {
        # Try with docker
        $dockerNvidiaSmi = docker run --rm -e NVIDIA_VISIBLE_DEVICES=all -e NVIDIA_DRIVER_CAPABILITIES=compute,utility --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi 2>$null
        if ($LASTEXITCODE -eq 0) {
            $gpuAvailable = $true
            Write-Host "✅ NVIDIA GPU support detected through Docker" -ForegroundColor $GREEN
        }
    }

    if (-not $gpuAvailable) {
        Write-Host "⚠️ No NVIDIA GPU detected. Running in CPU-only mode will be significantly slower." -ForegroundColor $YELLOW

        $continue = Read-Host "Do you want to continue without GPU acceleration? (Y/N)"
        if ($continue -ne "Y" -and $continue -ne "y") {
            Write-Host "Operation aborted." -ForegroundColor $YELLOW
            exit 0
        }
    }
} catch {
    Write-Host "⚠️ Could not check GPU availability: $_" -ForegroundColor $YELLOW
    Write-Host "Assuming no GPU is available." -ForegroundColor $YELLOW
}

# Set up RAM disk if not skipped
if (-not $SkipRamDiskSetup) {
    Write-Host "Setting up RAM disk for model data..." -ForegroundColor $CYAN

    $ramDiskScriptPath = Join-Path -Path $PSScriptRoot -ChildPath ".toolbox\docker\Setup-RamDiskForLLM.ps1"
    if (Test-Path $ramDiskScriptPath) {
        $ramDiskParams = @{
            RamDiskSize = $RamDiskSize
            ModelName = "smoll2"
        }

        if ($WhatIf) {
            Write-Host "WhatIf: Would run $ramDiskScriptPath with parameters:" -ForegroundColor $YELLOW
            $ramDiskParams.GetEnumerator() | ForEach-Object {
                Write-Host "  $($_.Key) = $($_.Value)" -ForegroundColor $WHITE
            }
        } else {
            & $ramDiskScriptPath @ramDiskParams

            if ($LASTEXITCODE -ne 0) {
                Write-Host "⚠️ RAM disk setup completed with warnings or errors" -ForegroundColor $YELLOW

                $continue = Read-Host "Do you want to continue? (Y/N)"
                if ($continue -ne "Y" -and $continue -ne "y") {
                    Write-Host "Operation aborted." -ForegroundColor $YELLOW
                    exit 0
                }
            } else {
                Write-Host "✅ RAM disk setup completed successfully" -ForegroundColor $GREEN
            }
        }
    } else {
        Write-Host "❌ RAM disk setup script not found at $ramDiskScriptPath" -ForegroundColor $RED
        Write-Host "Skipping RAM disk setup. This may affect performance." -ForegroundColor $YELLOW
    }
}

# Pull or update the smoll2 image using Docker Model Runner
try {
    Write-Host "Pulling smoll2 model from Docker Model Runner..." -ForegroundColor $CYAN

    if ($WhatIf) {
        Write-Host "WhatIf: Would run 'docker model pull ai/smoll2:latest'" -ForegroundColor $YELLOW
    } else {
        docker model pull ai/smoll2:latest

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to pull smoll2 model from Docker Model Runner" -ForegroundColor $RED
            Write-Host "Make sure Docker Model Runner is enabled in Docker Desktop settings" -ForegroundColor $WHITE
            exit 1
        }

        Write-Host "✅ Successfully pulled smoll2 model" -ForegroundColor $GREEN
    }
} catch {
    Write-Host "❌ Error pulling smoll2 model: $_" -ForegroundColor $RED
    exit 1
}

# Start the model with appropriate configuration
Write-Host "Starting smoll2 model with RAM disk and GPU acceleration..." -ForegroundColor $CYAN

if ($DockerSwarm) {
    # Docker Swarm deployment
    $swarmConfigPath = Join-Path -Path $PSScriptRoot -ChildPath ".devcontainer\swarm\smoll2-swarm-config.yml"

    if (-not (Test-Path $swarmConfigPath)) {
        Write-Host "❌ Swarm configuration file not found at $swarmConfigPath" -ForegroundColor $RED
        exit 1
    }

    if ($WhatIf) {
        Write-Host "WhatIf: Would deploy to Docker Swarm using $swarmConfigPath" -ForegroundColor $YELLOW
    } else {
        # Check if swarm is initialized
        $swarmStatus = docker info --format '{{.Swarm.LocalNodeState}}'

        if ($swarmStatus -ne "active") {
            Write-Host "Initializing Docker Swarm..." -ForegroundColor $CYAN
            docker swarm init
        }

        # Deploy the stack
        docker stack deploy -c $swarmConfigPath smoll2

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to deploy smoll2 stack to Docker Swarm" -ForegroundColor $RED
            exit 1
        }

        Write-Host "✅ Successfully deployed smoll2 to Docker Swarm" -ForegroundColor $GREEN
        Write-Host "📊 Monitor the deployment with 'docker stack services smoll2'" -ForegroundColor $WHITE
    }
} else {
    # Docker Compose deployment
    $composeConfigPath = Join-Path -Path $PSScriptRoot -ChildPath ".devcontainer\docker\smoll2-gpu-ramdisk.yml"

    if (-not (Test-Path $composeConfigPath)) {
        Write-Host "❌ Docker Compose configuration file not found at $composeConfigPath" -ForegroundColor $RED
        exit 1
    }

    $envVars = @{
        "SMOLL2_IMAGE" = "ai/smoll2:latest"
        "NVIDIA_VISIBLE_DEVICES" = $GpuDevices
    }

    # Build the docker-compose command
    $dockerComposeCmd = "docker-compose -f `"$composeConfigPath`" up -d"

    if ($ForceRebuild) {
        $dockerComposeCmd += " --build --force-recreate"
    }

    if ($WhatIf) {
        Write-Host "WhatIf: Would run '$dockerComposeCmd' with environment:" -ForegroundColor $YELLOW
        $envVars.GetEnumerator() | ForEach-Object {
            Write-Host "  $($_.Key)=$($_.Value)" -ForegroundColor $WHITE
        }
    } else {
        # Export environment variables
        foreach ($key in $envVars.Keys) {
            Set-Item -Path "env:$key" -Value $envVars[$key]
        }

        # Start the services
        Invoke-Expression $dockerComposeCmd

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to start smoll2 with Docker Compose" -ForegroundColor $RED
            exit 1
        }

        Write-Host "✅ Successfully started smoll2" -ForegroundColor $GREEN
        Write-Host "📊 Monitor the container with 'docker logs autogen-smoll2-gpu -f'" -ForegroundColor $WHITE
    }
}

# Display connection information
Write-Host "`nℹ️ Connection Information" -ForegroundColor $CYAN
Write-Host "Model endpoint: http://localhost:8080/v1/chat/completions" -ForegroundColor $WHITE
Write-Host "For Python usage:"
Write-Host "```python" -ForegroundColor $WHITE
Write-Host "from openai import OpenAI" -ForegroundColor $WHITE
Write-Host "client = OpenAI(base_url='http://localhost:8080/v1', api_key='default-dev-key')" -ForegroundColor $WHITE
Write-Host "response = client.chat.completions.create(" -ForegroundColor $WHITE
Write-Host "    model='smoll2'," -ForegroundColor $WHITE
Write-Host "    messages=[{'role': 'user', 'content': 'Hello world'}]" -ForegroundColor $WHITE
Write-Host ")" -ForegroundColor $WHITE
Write-Host "print(response.choices[0].message.content)" -ForegroundColor $WHITE
Write-Host "```" -ForegroundColor $WHITE

exit 0
