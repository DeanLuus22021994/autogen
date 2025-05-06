# PowerShell script to optimize Docker Swarm for GPU workloads
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ApplyChanges,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0.1, 1.0)]
    [double]$MemoryFraction = 0.8,

    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# Import required modules
$modulesToLoad = @(
    @{
        Path = (Join-Path -Path $PSScriptRoot -ChildPath "..\modules\ProblemManagement.psm1")
        Name = "ProblemManagement"
    }
)

foreach ($module in $modulesToLoad) {
    if (Test-Path -Path $module.Path) {
        Import-Module -Name $module.Path -Force
        if ($Verbose) {
            Write-Host "Imported module: $($module.Name)" -ForegroundColor Green
        }
    } else {
        Write-Error "Required module not found: $($module.Path)"
        exit 1
    }
}

# Banner
Write-Host "-----------------------------------------------------" -ForegroundColor Cyan
Write-Host "Docker Swarm GPU Optimization Tool" -ForegroundColor Cyan
Write-Host "Optimizes Docker Swarm for NVIDIA GPU workloads" -ForegroundColor Cyan
Write-Host "-----------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# Check if running with admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "This script should be run with administrator privileges for full functionality."
    Write-Warning "Some operations may fail without elevated permissions."
}

# Check for GPU availability
$gpuAvailable = Test-GPUAvailability
if (-not $gpuAvailable) {
    Write-Warning "No NVIDIA GPUs detected. Optimization will be limited."

    if (-not $Force) {
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
}

# Check Docker installation and version
try {
    $dockerVersion = (docker version --format '{{.Server.Version}}' 2>$null)
    if (-not $dockerVersion) {
        Write-Error "Docker is not running or not installed. Please install Docker and try again."
        exit 1
    }

    Write-Host "Docker version: $dockerVersion" -ForegroundColor Green

    # Check Docker Swarm status
    $swarmStatus = (docker info --format '{{.Swarm.LocalNodeState}}' 2>$null)
    if ($swarmStatus -ne "active") {
        Write-Host "Docker Swarm is not active." -ForegroundColor Yellow

        if ($ApplyChanges) {
            Write-Host "Initializing Docker Swarm..." -ForegroundColor Cyan
            docker swarm init
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to initialize Docker Swarm."
                exit 1
            }
            Write-Host "Docker Swarm initialized successfully." -ForegroundColor Green
        } else {
            Write-Host "Run with -ApplyChanges to initialize Docker Swarm." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Docker Swarm is active." -ForegroundColor Green

        # Get Swarm node information
        $nodeCount = (docker node ls --format '{{.Hostname}}' | Measure-Object -Line).Lines
        Write-Host "Swarm has $nodeCount node(s)." -ForegroundColor Green
    }
} catch {
    Write-Error "Error checking Docker: $_"
    exit 1
}

# Optimize Docker configuration for GPU
if ($ApplyChanges) {
    Write-Host "Optimizing Docker daemon configuration for GPU support..." -ForegroundColor Cyan
    $result = Optimize-DockerConfiguration -EnableGPU -EnableSwarm -Force:$Force

    if ($result) {
        Write-Host "Docker configuration optimized successfully." -ForegroundColor Green
    } else {
        Write-Warning "Docker configuration optimization skipped or failed."
    }

    # Create Docker Compose file for GPU-enabled services
    $composeDir = Join-Path -Path $PSScriptRoot -ChildPath "swarm-compose"
    if (-not (Test-Path $composeDir)) {
        New-Item -Path $composeDir -ItemType Directory -Force | Out-Null
    }

    $composeFile = Join-Path -Path $composeDir -ChildPath "gpu-services.yml"

    # Define compose file content
    $composeContent = @"
# Docker Compose configuration for GPU-accelerated services in Swarm
version: '3.8'

x-gpu-options: &gpu-options
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: 1
            capabilities: [gpu, compute, utility]
  environment:
    - NVIDIA_VISIBLE_DEVICES=all
    - NVIDIA_DRIVER_CAPABILITIES=compute,utility
    - GPU_MEMORY_FRACTION=$MemoryFraction

services:
  # Base configuration for a GPU-accelerated model runner
  model-runner:
    <<: *gpu-options
    image: autogen/model-runner:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - model-cache:/opt/models
    networks:
      - autogen-network
    deploy:
      mode: replicated
      replicas: 1
      resources:
        limits:
          memory: 8G
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  # GPU-accelerated development container
  dev-environment:
    <<: *gpu-options
    image: autogen/devcontainer:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - source-code:/workspaces/autogen
    networks:
      - autogen-network
    deploy:
      mode: replicated
      replicas: 1
    command: sleep infinity

networks:
  autogen-network:
    driver: overlay
    attachable: true

volumes:
  model-cache:
    driver: local
  source-code:
    driver: local
"@

    # Save compose file
    Set-Content -Path $composeFile -Value $composeContent
    Write-Host "Created GPU-optimized Docker Compose file at: $composeFile" -ForegroundColor Green

    # Create helper script to deploy services
    $deployScript = Join-Path -Path $composeDir -ChildPath "deploy-gpu-services.ps1"
    $deployScriptContent = @"
# Deploy GPU-optimized services to Docker Swarm
[CmdletBinding()]
param()

Write-Host "Deploying GPU-optimized services to Docker Swarm..." -ForegroundColor Cyan

# Check if Swarm is active
`$swarmStatus = (docker info --format '{{.Swarm.LocalNodeState}}' 2>`$null)
if (`$swarmStatus -ne "active") {
    Write-Error "Docker Swarm is not active. Initialize Swarm with 'docker swarm init' first."
    exit 1
}

# Create network if it doesn't exist
docker network create --driver overlay --attachable autogen-network 2>`$null
Write-Host "Ensuring autogen-network exists." -ForegroundColor Green

# Create volumes if they don't exist
docker volume create model-cache 2>`$null
docker volume create source-code 2>`$null
Write-Host "Ensuring required volumes exist." -ForegroundColor Green

# Deploy the stack
docker stack deploy -c "$composeFile" autogen-gpu
if (`$LASTEXITCODE -eq 0) {
    Write-Host "GPU-optimized services deployed successfully." -ForegroundColor Green

    # Give services time to start
    Write-Host "Waiting for services to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5

    # Show service status
    docker service ls --filter name=autogen-gpu
} else {
    Write-Error "Failed to deploy GPU-optimized services."
    exit 1
}
"@

    # Save deploy script
    Set-Content -Path $deployScript -Value $deployScriptContent
    Write-Host "Created deployment script at: $deployScript" -ForegroundColor Green
}

Write-Host ""
Write-Host "Docker Swarm GPU optimization tasks completed." -ForegroundColor Cyan

if ($ApplyChanges) {
    Write-Host "Changes applied. To deploy GPU-optimized services, run the deployment script." -ForegroundColor Green
} else {
    Write-Host "Run with -ApplyChanges to apply the optimizations." -ForegroundColor Yellow
}

Write-Host "-----------------------------------------------------" -ForegroundColor Cyan
