# PowerShell script to set up RAM disk for high-performance model inference

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$RamDiskSize = "8G",

    [Parameter(Mandatory = $false)]
    [string]$MountPoint = "/mnt/ramdisk",

    [Parameter(Mandatory = $false)]
    [string]$ModelCachePath = "/opt/autogen/models",

    [Parameter(Mandatory = $false)]
    [string]$ModelName = "smoll2",

    [Parameter(Mandatory = $false)]
    [switch]$AddToFstab,

    [Parameter(Mandatory = $false)]
    [switch]$InContainer
)

$ErrorActionPreference = 'Stop'
$GREEN = [ConsoleColor]::Green
$YELLOW = [ConsoleColor]::Yellow
$RED = [ConsoleColor]::Red
$CYAN = [ConsoleColor]::Cyan
$WHITE = [ConsoleColor]::White

function Test-IsAdministrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsWsl {
    return [System.Environment]::OSVersion.Platform -eq "Unix" -and (Get-Content /proc/version -ErrorAction SilentlyContinue) -match "Microsoft"
}

function Test-IsLinux {
    return [System.Environment]::OSVersion.Platform -eq "Unix"
}

function Test-IsDocker {
    return (Test-Path -Path "/.dockerenv" -ErrorAction SilentlyContinue) -or
          ((Get-Content -Path "/proc/1/cgroup" -ErrorAction SilentlyContinue) -match "/docker/" -or
           (Get-Content -Path "/proc/self/cgroup" -ErrorAction SilentlyContinue) -match "/docker/")
}

Write-Host "🚀 RAM disk setup for high-performance LLM inference" -ForegroundColor $CYAN

# Check if running in Windows
if (-not (Test-IsLinux)) {
    if ($InContainer) {
        Write-Host "Running inside a container on Windows host. Will set up RAM disk inside the container." -ForegroundColor $YELLOW
    } else {
        Write-Host "⚠️ This script is designed for Linux/WSL environments. In Windows, consider:" -ForegroundColor $YELLOW
        Write-Host "  1. Use WSL and run this script inside WSL" -ForegroundColor $WHITE
        Write-Host "  2. For Windows hosts, use ImDisk or similar for RAM disk creation" -ForegroundColor $WHITE
        Write-Host "  3. Run Docker with -v to mount the RAM disk into containers" -ForegroundColor $WHITE
        Write-Host ""

        $continue = Read-Host "Do you want to continue and run this in Docker? (Y/N)"
        if ($continue -ne "Y" -and $continue -ne "y") {
            Write-Host "Aborted RAM disk setup" -ForegroundColor $YELLOW
            return
        }

        # Run the setup inside the Dev Container
        Write-Host "Running setup inside the Dev Container..." -ForegroundColor $CYAN
        docker exec -it autogen-dev bash -c "cd /workspace/.toolbox/docker && bash setup-ramdisk.sh"
        return
    }
}

# Check if running as root/administrator in Linux
if (Test-IsLinux -and -not (Test-IsDocker) -and -not ((id -u) -eq 0)) {
    Write-Host "⚠️ This script must be run as root in Linux environments" -ForegroundColor $RED
    Write-Host "Please run with sudo or as root user" -ForegroundColor $WHITE
    return
}

# Set environment variables for the bash script
$envVars = @{
    "RAMDISK_SIZE" = $RamDiskSize
    "RAMDISK_MOUNT_POINT" = $MountPoint
    "MODEL_CACHE_PATH" = $ModelCachePath
    "MODEL_NAME" = $ModelName
    "ADD_TO_FSTAB" = if ($AddToFstab) { "true" } else { "false" }
}

# Build the environment variable exports for bash
$envExports = $envVars.Keys | ForEach-Object { "export $_=`"$($envVars[$_])`"" }

# Build the command to run the bash script with environment variables
$bashScript = Join-Path -Path $PSScriptRoot -ChildPath "setup-ramdisk.sh"
$cmd = @"
$($envExports -join "; ")
bash "$bashScript"
"@

# If in Linux, run the script directly
if (Test-IsLinux) {
    Write-Host "Running RAM disk setup script..." -ForegroundColor $CYAN
    bash -c $cmd

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ RAM disk setup completed successfully" -ForegroundColor $GREEN
    } else {
        Write-Host "❌ RAM disk setup failed with exit code $LASTEXITCODE" -ForegroundColor $RED
    }
} else {
    # In Windows, provide instructions for manual setup
    Write-Host "Manual setup required for Windows hosts:" -ForegroundColor $YELLOW
    Write-Host "1. Create a RAM disk using ImDisk or similar tools" -ForegroundColor $WHITE
    Write-Host "2. When running Docker, mount the RAM disk using:" -ForegroundColor $WHITE
    Write-Host "   docker run -v X:\path\to\ramdisk:/opt/autogen/models ..." -ForegroundColor $CYAN
    Write-Host "3. Set environment variables in your container:" -ForegroundColor $WHITE
    Write-Host "   - MODEL_PATH=/opt/autogen/models/smoll2" -ForegroundColor $CYAN
}

# Output Docker configuration snippet
Write-Host "`nDocker configuration snippet:" -ForegroundColor $CYAN
Write-Host "```yaml" -ForegroundColor $WHITE
Write-Host "services:" -ForegroundColor $WHITE
Write-Host "  smoll2-service:" -ForegroundColor $WHITE
Write-Host "    volumes:" -ForegroundColor $WHITE
Write-Host "      - $MountPoint:$ModelCachePath" -ForegroundColor $WHITE
Write-Host "    environment:" -ForegroundColor $WHITE
Write-Host "      - MODEL_PATH=$ModelCachePath/$ModelName" -ForegroundColor $WHITE
Write-Host "```" -ForegroundColor $WHITE
