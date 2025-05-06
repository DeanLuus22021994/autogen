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
    }

    # Configure GPU support if requested
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