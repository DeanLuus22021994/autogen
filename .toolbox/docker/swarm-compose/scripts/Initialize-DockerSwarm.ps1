# Initialize-DockerSwarm.ps1
<#
.SYNOPSIS
    Initializes a Docker Swarm environment.

.DESCRIPTION
    This script initializes a Docker Swarm environment and sets up necessary configurations
    for running AutoGen in a distributed environment.

.PARAMETER AdvertiseAddr
    Optional. The IP address to advertise for the Swarm manager.

.PARAMETER EnableGPU
    Optional. If specified, configures the environment for GPU support.

.PARAMETER ListenPort
    Optional. The port to listen on for Swarm communication. Default is 2377.

.EXAMPLE
    .\Initialize-DockerSwarm.ps1

.EXAMPLE
    .\Initialize-DockerSwarm.ps1 -AdvertiseAddr 192.168.1.100 -EnableGPU
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$AdvertiseAddr,

    [Parameter(Mandatory = $false)]
    [switch]$EnableGPU,

    [Parameter(Mandatory = $false)]
    [int]$ListenPort = 2377
)

function Test-DockerRunning {
    try {
        $dockerStatus = docker info 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Test-SwarmActive {
    try {
        $swarmStatus = docker info --format '{{.Swarm.LocalNodeState}}'
        return $swarmStatus -eq "active"
    } catch {
        return $false
    }
}

function Test-GPUSupport {
    try {
        $nvidiaOutput = docker run --rm --gpus all nvidia/cuda:12.0.1-base-ubuntu22.04 nvidia-smi
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Initialize-Swarm {
    param (
        [string]$AdvertiseAddrParam,
        [int]$ListenPortParam
    )

    $initCommand = "docker swarm init"

    if ($AdvertiseAddrParam) {
        $initCommand += " --advertise-addr $AdvertiseAddrParam"
    }

    if ($ListenPortParam -ne 2377) {
        $initCommand += " --listen-addr 0.0.0.0:$ListenPortParam"
    }

    Write-Host "Initializing Docker Swarm with command: $initCommand" -ForegroundColor Cyan
    Invoke-Expression $initCommand

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to initialize Docker Swarm"
        exit 1
    }

    Write-Host "Docker Swarm initialized successfully" -ForegroundColor Green
}

function Set-GPUSupport {
    <#
    .SYNOPSIS
        Configures Docker for GPU support.

    .DESCRIPTION
        Sets up Docker daemon configuration to support NVIDIA GPU runtime
        by modifying the daemon.json file.
    #>
    # Check if Docker Daemon is configured for NVIDIA GPU runtime
    $daemonConfigPath = if ($IsWindows) { "$env:ProgramData\Docker\config\daemon.json" } else { "/etc/docker/daemon.json" }

    if (Test-Path $daemonConfigPath) {
        $daemonConfig = Get-Content -Path $daemonConfigPath -Raw | ConvertFrom-Json
    } else {
        $daemonConfig = [PSCustomObject]@{}
    }

    # Check if runtimes are already configured
    $modified = $false

    if (-not ($daemonConfig.PSObject.Properties.Name -contains "runtimes")) {
        Add-Member -InputObject $daemonConfig -MemberType NoteProperty -Name "runtimes" -Value @{}
        $modified = $true
    }

    # Add NVIDIA runtime if not present
    if (-not ($daemonConfig.runtimes.PSObject.Properties.Name -contains "nvidia")) {
        $daemonConfig.runtimes | Add-Member -MemberType NoteProperty -Name "nvidia" -Value @{
            "path" = if ($IsWindows) { "nvidia-container-runtime" } else { "/usr/bin/nvidia-container-runtime" }
        }
        $modified = $true
    }

    # Set NVIDIA as default runtime if requested
    if ($EnableGPU -and -not ($daemonConfig.PSObject.Properties.Name -contains "default-runtime")) {
        Add-Member -InputObject $daemonConfig -MemberType NoteProperty -Name "default-runtime" -Value "nvidia"
        $modified = $true
    }

    # Save changes if any were made
    if ($modified) {
        if (-not (Test-Path (Split-Path $daemonConfigPath -Parent))) {
            New-Item -Path (Split-Path $daemonConfigPath -Parent) -ItemType Directory -Force | Out-Null
        }

        $daemonConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $daemonConfigPath
        Write-Host "Docker daemon configured for NVIDIA GPU support" -ForegroundColor Green
        Write-Host "Please restart Docker for the changes to take effect" -ForegroundColor Yellow
    }
}

# Main script
try {
    # Check if Docker is running
    if (-not (Test-DockerRunning)) {
        Write-Error "Docker is not running. Please start Docker and try again."
        exit 1
    }

    # Check if Swarm is already active
    if (Test-SwarmActive) {
        Write-Host "Docker Swarm is already active" -ForegroundColor Green

        # Display Swarm information
        Write-Host "Current Swarm status:" -ForegroundColor Cyan
        docker node ls
    } else {
        # Initialize Swarm
        Initialize-Swarm -AdvertiseAddrParam $AdvertiseAddr -ListenPortParam $ListenPort

        # Display join token for adding workers
        Write-Host "`nTo add a worker to this swarm, run the following command on the worker node:" -ForegroundColor Yellow
        $joinToken = docker swarm join-token worker -q
        Write-Host "docker swarm join --token $joinToken $(if ($AdvertiseAddr) { $AdvertiseAddr } else { "MANAGER_IP" }):$ListenPort" -ForegroundColor White
    }

    # Configure GPU support if requested
    if ($EnableGPU) {
        Write-Host "`nConfiguring GPU support..." -ForegroundColor Cyan

        if (Test-GPUSupport) {
            Write-Host "GPU support is already configured and functioning" -ForegroundColor Green
        } else {
            Set-GPUSupport
            Write-Host "After restarting Docker, verify GPU support with: docker run --rm --gpus all nvidia/cuda:12.0.1-base-ubuntu22.04 nvidia-smi" -ForegroundColor Yellow
        }
    }

    # Display next steps
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Create or customize your deployment configuration in the configs/ directory" -ForegroundColor White
    Write-Host "2. Use the 'Deploy Swarm Stack' task in VS Code to deploy your stack" -ForegroundColor White
    Write-Host "3. Monitor your services with 'docker service ls' or the 'Monitor Swarm Services' task" -ForegroundColor White

} catch {
    Write-Error "Error initializing Docker Swarm: $_"
    exit 1
}
