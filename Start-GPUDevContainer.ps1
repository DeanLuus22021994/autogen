# Script to start the GPU-optimized DevContainer
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$Rebuild,

    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Banner
Write-Host "-----------------------------------------------------" -ForegroundColor Cyan
Write-Host "AutoGen GPU-Optimized DevContainer Launcher" -ForegroundColor Cyan
Write-Host "-----------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# Import GPU detection function from ProblemManagement module
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath ".toolbox\modules\ProblemManagement.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
    Write-Host "Imported ProblemManagement module." -ForegroundColor Green
} else {
    Write-Warning "Could not find ProblemManagement module at: $modulePath"
    Write-Warning "GPU detection may be limited."

    # Define a simplified version of the GPU detection function
    function Test-GPUAvailability {
        try {
            $nvidiaSmi = Get-Command -Name "nvidia-smi" -ErrorAction SilentlyContinue
            if ($nvidiaSmi) {
                $gpuInfo = & nvidia-smi --query-gpu=name --format=csv,noheader
                if ($gpuInfo) {
                    Write-Host "NVIDIA GPU detected: $gpuInfo" -ForegroundColor Green
                    return $true
                }
            }
            return $false
        } catch {
            Write-Verbose "Error checking for GPU: $_"
            return $false
        }
    }
}

# Check for GPU availability
$gpuAvailable = Test-GPUAvailability
if (-not $gpuAvailable) {
    Write-Warning "No NVIDIA GPUs detected. Running the GPU-optimized container may fail."

    if (-not $Force) {
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            Write-Host "Operation cancelled. Use -Force to start without GPU detection." -ForegroundColor Yellow
            exit 0
        }
    }
}

# Check if Docker is running
try {
    $dockerRunning = docker info 2>$null
    if (-not $dockerRunning) {
        Write-Error "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    }
} catch {
    Write-Error "Error checking Docker: $_"
    Write-Error "Please make sure Docker is installed and running."
    exit 1
}

# Optimize Docker configuration for GPU if needed
Write-Host "Checking Docker configuration for GPU support..." -ForegroundColor Cyan
$daemonConfigPath = "$env:USERPROFILE\.docker\daemon.json"
$configureDocker = $false

if (Test-Path $daemonConfigPath) {
    try {
        $config = Get-Content -Path $daemonConfigPath -Raw | ConvertFrom-Json

        # Check for NVIDIA runtime
        if (-not (Get-Member -InputObject $config -Name "runtimes" -MemberType Properties) -or
            -not ($config.runtimes.PSObject.Properties.Name -contains "nvidia")) {
            $configureDocker = $true
        }
    } catch {
        Write-Warning "Could not read Docker configuration: $_"
        $configureDocker = $true
    }
} else {
    $configureDocker = $true
}

if ($configureDocker) {
    Write-Host "Docker configuration needs to be updated for GPU support." -ForegroundColor Yellow

    if ($Force -or (Read-Host "Update Docker configuration for GPU support? (Y/n)") -ne "n") {
        Write-Host "Optimizing Docker configuration for GPU support..." -ForegroundColor Green

        # Update Docker configuration for GPU support
        $toolboxPath = Join-Path -Path $PSScriptRoot -ChildPath ".toolbox\docker\Optimize-DockerSwarmGPU.ps1"
        if (Test-Path $toolboxPath) {
            & $toolboxPath -ApplyChanges -Force:$Force -Verbose:$Verbose
        } else {
            # Fall back to basic module function
            Write-Host "Using basic Docker configuration optimization..." -ForegroundColor Yellow
            Optimize-DockerConfiguration -EnableGPU -Force:$Force
        }

        Write-Host "Docker configuration updated. You may need to restart Docker for changes to take effect." -ForegroundColor Yellow
        $restartDocker = Read-Host "Restart Docker now? (y/N)"

        if ($restartDocker -eq "y" -or $restartDocker -eq "Y") {
            Write-Host "Restarting Docker Desktop..." -ForegroundColor Cyan
            Restart-Service com.docker.service -Force
            Start-Sleep -Seconds 10
            Write-Host "Docker Desktop restarted. Please run this script again after Docker is fully running." -ForegroundColor Green
            exit 0
        }
    }
}

# Launch the GPU-optimized DevContainer
Write-Host "Launching GPU-optimized DevContainer..." -ForegroundColor Cyan

# Set working directory to the DevContainer directory
$devContainerPath = Join-Path -Path $PSScriptRoot -ChildPath ".devcontainer"
Set-Location $devContainerPath

# Docker Compose command
$composeCommand = "docker-compose -f docker-compose.gpu.yml"
if ($Rebuild) {
    $composeCommand += " build --no-cache devcontainer"
}
$composeCommand += " up -d"

# Execute the command
Write-Host "Running: $composeCommand" -ForegroundColor Green
Invoke-Expression $composeCommand

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to start GPU-optimized DevContainer."
    exit 1
}

Write-Host "GPU-optimized DevContainer started successfully." -ForegroundColor Green
Write-Host ""
Write-Host "To connect to the container in VS Code:"
Write-Host "1. Open VS Code"
Write-Host "2. Install the 'Remote - Containers' extension if not already installed"
Write-Host "3. Click on the remote connection icon in the bottom-left corner"
Write-Host "4. Select 'Attach to Running Container...' and choose the autogen devcontainer"
Write-Host ""
Write-Host "To stop the container, run: docker-compose -f docker-compose.gpu.yml down"
Write-Host "-----------------------------------------------------" -ForegroundColor Cyan
