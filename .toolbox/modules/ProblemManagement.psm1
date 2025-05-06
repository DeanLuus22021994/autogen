function Test-GPUAvailability {
    [CmdletBinding()]
    param()

    try {
        # Check if nvidia-smi is available
        $nvidiaSmi = Get-Command -Name "nvidia-smi" -ErrorAction SilentlyContinue

        if ($null -ne $nvidiaSmi) {
            $gpuInfo = & nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader

            if ($null -ne $gpuInfo -and $gpuInfo.Count -gt 0) {
                Write-Host "NVIDIA GPU detected:" -ForegroundColor Green
                $gpuInfo | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
                return $true
            }
        }

        # If nvidia-smi is not available or returned no GPUs
        Write-Verbose "No NVIDIA GPUs detected."
        return $false
    }
    catch {
        Write-Verbose "Error checking for NVIDIA GPUs: $_"
        return $false
    }
}

function Start-GPUAcceleratedTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [int]$GPUMemoryReservationMB = 4096,

        [Parameter(Mandatory = $false)]
        [switch]$UseSwarm,

        [Parameter(Mandatory = $false)]
        [switch]$Detached
    )

    # Check if GPU is available
    if (-not (Test-GPUAvailability)) {
        Write-Warning "No NVIDIA GPU detected. Task will run without GPU acceleration."
        # Run the command without GPU acceleration
        Invoke-Expression $Command
        return
    }

    $dockerRunOptions = "--gpus all"

    if ($GPUMemoryReservationMB -gt 0) {
        $dockerRunOptions += " --env NVIDIA_VISIBLE_DEVICES=all --env NVIDIA_DRIVER_CAPABILITIES=all --env CUDA_VISIBLE_DEVICES=0"
        $dockerRunOptions += " --env NVIDIA_MEM_RESERVATION=${GPUMemoryReservationMB}m"
    }

    if ($Detached) {
        $dockerRunOptions += " -d"
    }

    if ($UseSwarm) {
        # Check if we're in a swarm
        $swarmStatus = docker info --format "{{.Swarm.LocalNodeState}}"

        if ($swarmStatus -ne "active") {
            Write-Warning "Docker Swarm is not active. Initializing swarm..."
            docker swarm init
        }

        $serviceCommand = "docker service create --name $TaskName $dockerRunOptions $Command"
        Write-Verbose "Running GPU-accelerated task in Swarm: $serviceCommand"
        Invoke-Expression $serviceCommand
    }
    else {
        $runCommand = "docker run --name $TaskName $dockerRunOptions $Command"
        Write-Verbose "Running GPU-accelerated task: $runCommand"
        Invoke-Expression $runCommand
    }
}

function Optimize-DockerConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$EnableGPU,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$PreserveExisting,

        [Parameter(Mandatory = $false)]
        [switch]$EnableSwarm,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$MaxConcurrentDownloads = 50,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$MaxConcurrentUploads = 50,

        [Parameter(Mandatory = $false)]
        [ValidateRange(10, 1000)]
        [string]$DefaultKeepStorage = "250GB"
    )

    $daemonConfigPath = "$env:USERPROFILE\.docker\daemon.json"
    $configDir = Split-Path -Path $daemonConfigPath -Parent

    # Create directory if it doesn't exist
    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }

    # Load existing configuration or create new one
    if (Test-Path $daemonConfigPath) {
        try {
            $config = Get-Content -Path $daemonConfigPath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Warning "Invalid daemon.json file. Creating a new one."
            $config = [PSCustomObject]@{}
        }
    }
    else {
        $config = [PSCustomObject]@{}
    }

    $modified = $false

    # Configure Model Runner settings
    if (-not (Get-Member -InputObject $config -Name "model-runner" -MemberType Properties)) {
        Add-Member -InputObject $config -MemberType NoteProperty -Name "model-runner" -Value @{
            "enabled" = $true
            "port" = 6000
        }
        $modified = $true
    }

    # Configure experimental features
    if (-not (Get-Member -InputObject $config -Name "experimental" -MemberType Properties)) {
        Add-Member -InputObject $config -Name "experimental" -MemberType NoteProperty -Value $true
        $modified = $true
    }

    # Configure BuildKit
    if (-not (Get-Member -InputObject $config -Name "features" -MemberType Properties)) {
        Add-Member -InputObject $config -MemberType NoteProperty -Name "features" -Value @{
            "buildkit" = $true
        }
        $modified = $true
    }
    elseif (-not (Get-Member -InputObject $config.features -Name "buildkit" -MemberType Properties)) {
        Add-Member -InputObject $config.features -MemberType NoteProperty -Name "buildkit" -Value $true
        $modified = $true
    }

    # Configure Builder GC
    if (-not (Get-Member -InputObject $config -Name "builder" -MemberType Properties)) {
        Add-Member -InputObject $config -MemberType NoteProperty -Name "builder" -Value @{
            "gc" = @{
                "defaultKeepStorage" = $DefaultKeepStorage
                "enabled" = $true
            }
        }
        $modified = $true
    }
    elseif (-not (Get-Member -InputObject $config.builder -Name "gc" -MemberType Properties)) {
        Add-Member -InputObject $config.builder -MemberType NoteProperty -Name "gc" -Value @{
            "defaultKeepStorage" = $DefaultKeepStorage
            "enabled" = $true
        }
        $modified = $true
    }

    # Configure DNS
    if (-not (Get-Member -InputObject $config -Name "dns" -MemberType Properties)) {
        Add-Member -InputObject $config -MemberType NoteProperty -Name "dns" -Value @(
            "8.8.8.8",
            "8.8.4.4",
            "1.1.1.1"
        )
        $modified = $true
    }

    # Configure max concurrent downloads/uploads
    if (-not (Get-Member -InputObject $config -Name "max-concurrent-downloads" -MemberType Properties)) {
        Add-Member -InputObject $config -MemberType NoteProperty -Name "max-concurrent-downloads" -Value $MaxConcurrentDownloads
        $modified = $true
    }

    if (-not (Get-Member -InputObject $config -Name "max-concurrent-uploads" -MemberType Properties)) {
        Add-Member -InputObject $config -MemberType NoteProperty -Name "max-concurrent-uploads" -Value $MaxConcurrentUploads
        $modified = $true
    }    # Configure GPU support if requested
    if ($EnableGPU) {
        if (-not (Get-Member -InputObject $config -Name "runtimes" -MemberType Properties)) {
            Add-Member -InputObject $config -MemberType NoteProperty -Name "runtimes" -Value @{
                "nvidia" = @{
                    "path" = "nvidia-container-runtime"
                    "runtimeArgs" = @()
                }
            }
            $modified = $true
        }
        elseif (-not ($config.runtimes.PSObject.Properties.Name -contains "nvidia")) {
            $config.runtimes | Add-Member -MemberType NoteProperty -Name "nvidia" -Value @{
                "path" = "nvidia-container-runtime"
                "runtimeArgs" = @()
            }
            $modified = $true
        }

        # Set as default runtime
        if (-not (Get-Member -InputObject $config -Name "default-runtime" -MemberType Properties) -or
            $config."default-runtime" -ne "nvidia") {

            if ((Get-Member -InputObject $config -Name "default-runtime" -MemberType Properties)) {
                $config."default-runtime" = "nvidia"
            }
            else {
                Add-Member -InputObject $config -MemberType NoteProperty -Name "default-runtime" -Value "nvidia"
            }
            $modified = $true
        }

        # Configure nvidia-container-runtime
        if (-not (Get-Member -InputObject $config -Name "nvidia-container-runtime" -MemberType Properties)) {
            Add-Member -InputObject $config -MemberType NoteProperty -Name "nvidia-container-runtime" -Value @{
                "debug" = "0"
                "log-level" = "info"
                "no-cgroups" = "false"
                "swarm-resource" = "DOCKER_RESOURCE_GPU"
            }
            $modified = $true
        }

        # Configure node-generic-resources for Swarm
        if ($EnableSwarm -and (-not (Get-Member -InputObject $config -Name "node-generic-resources" -MemberType Properties))) {
            Add-Member -InputObject $config -MemberType NoteProperty -Name "node-generic-resources" -Value @(
                "DOCKER_RESOURCE_GPU=0,1,2,3"  # Assumes up to 4 GPUs, will be adjusted based on actual hardware
            )
            $modified = $true
        }
    }

    # Save the configuration if modified
    if ($modified -or $Force) {
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $daemonConfigPath -Force
        Write-Host "Docker configuration updated. Please restart Docker Desktop for changes to take effect." -ForegroundColor Yellow
        return $true
    }
    else {
        Write-Host "Docker configuration is already optimized." -ForegroundColor Green
        return $false
    }
}