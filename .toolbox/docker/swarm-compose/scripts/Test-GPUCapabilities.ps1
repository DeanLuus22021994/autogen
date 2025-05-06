<#
.SYNOPSIS
    Tests NVIDIA GPU capabilities and compatibility for model inference.

.DESCRIPTION
    This script performs comprehensive tests of NVIDIA GPU capabilities
    to ensure proper functionality for AI model inference using Docker.
    It checks NVIDIA drivers, CUDA compatibility, and Docker GPU runtime.

.PARAMETER Verbose
    When specified, provides more detailed output for diagnostics.

.EXAMPLE
    .\Test-GPUCapabilities.ps1

.EXAMPLE
    .\Test-GPUCapabilities.ps1 -Verbose
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# Console colors for better readability
$CYAN = "Cyan"
$GREEN = "Green"
$YELLOW = "Yellow"
$RED = "Red"

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White",

        [Parameter(Mandatory = $false)]
        [switch]$NoNewline
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"

    if ($NoNewline) {
        Write-Host $logMessage -ForegroundColor $ForegroundColor -NoNewline
    }
    else {
        Write-Host $logMessage -ForegroundColor $ForegroundColor
    }
}

function Test-NvidiaDrivers {
    <#
    .SYNOPSIS
        Tests if NVIDIA drivers are installed and functioning.
    .DESCRIPTION
        Checks for the presence and functionality of NVIDIA drivers on the system
        by attempting to run the nvidia-smi command.
    #>
    Write-Log "🔍 Checking NVIDIA drivers..." -ForegroundColor $CYAN

    try {
        $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue

        if ($null -eq $nvidiaSmi) {
            Write-Log "❌ NVIDIA SMI tool not found. NVIDIA drivers may not be installed." -ForegroundColor $RED
            return $false
        }

        $driverInfo = & nvidia-smi --query-gpu=driver_version,name,temperature.gpu,utilization.gpu,memory.total --format=csv,noheader

        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ NVIDIA SMI failed to execute. Exit code: $LASTEXITCODE" -ForegroundColor $RED
            return $false
        }

        $driverVersion = ($driverInfo -split ",")[0].Trim()
        $gpuName = ($driverInfo -split ",")[1].Trim()
        $temperature = ($driverInfo -split ",")[2].Trim()
        $utilization = ($driverInfo -split ",")[3].Trim()
        $memory = ($driverInfo -split ",")[4].Trim()

        Write-Log "✅ NVIDIA drivers are installed and functioning." -ForegroundColor $GREEN
        Write-Log "   Driver Version: $driverVersion" -ForegroundColor $CYAN
        Write-Log "   GPU: $gpuName" -ForegroundColor $CYAN
        Write-Log "   Temperature: $temperature" -ForegroundColor $CYAN
        Write-Log "   Utilization: $utilization" -ForegroundColor $CYAN
        Write-Log "   Total Memory: $memory" -ForegroundColor $CYAN

        # Check minimum required driver version for CUDA 12.0
        $minimumVersion = [version]"525.60.13"
        $currentVersion = [version]($driverVersion -replace "\..*$")

        if ($currentVersion -lt $minimumVersion) {
            Write-Log "⚠️ Warning: Driver version $driverVersion may be too old for CUDA 12.0+ (min: 525.60.13)" -ForegroundColor $YELLOW
        }

        return $true
    }
    catch {
        Write-Log "❌ Error checking NVIDIA drivers: $_" -ForegroundColor $RED
        return $false
    }
}

function Test-DockerGPURuntime {
    <#
    .SYNOPSIS
        Tests if Docker is configured with GPU runtime support.
    .DESCRIPTION
        Verifies that Docker can access and use NVIDIA GPUs by running
        a test container that uses nvidia-smi.
    #>
    Write-Log "🔍 Checking Docker GPU runtime..." -ForegroundColor $CYAN

    try {
        # Test basic Docker functionality first
        $dockerVersion = docker version --format '{{.Server.Version}}'

        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ Docker command failed. Exit code: $LASTEXITCODE" -ForegroundColor $RED
            Write-Log "   Please ensure Docker is installed and running." -ForegroundColor $YELLOW
            return $false
        }

        # Test GPU support by running nvidia-smi in a container
        $gpuOutput = docker run --rm --gpus all nvidia/cuda:12.0.1-base-ubuntu22.04 nvidia-smi

        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ Docker GPU runtime test failed. Exit code: $LASTEXITCODE" -ForegroundColor $RED
            Write-Log "   Please ensure the NVIDIA Container Toolkit is installed and configured." -ForegroundColor $YELLOW
            Write-Log "   See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html" -ForegroundColor $YELLOW
            return $false
        }

        Write-Log "✅ Docker GPU runtime is configured correctly." -ForegroundColor $GREEN
        Write-Log "   GPU information from container:" -ForegroundColor $CYAN
        if ($Verbose) {
            Write-Log "$gpuOutput" -ForegroundColor $CYAN
        }
        else {
            Write-Log "   Run with -Verbose to see detailed GPU information" -ForegroundColor $CYAN
        }

        return $true
    }
    catch {
        Write-Log "❌ Error checking Docker GPU runtime: $_" -ForegroundColor $RED
        return $false
    }
}

function Test-DockerModelRunner {
    <#
    .SYNOPSIS
        Tests if Docker Model Runner is enabled and functioning.
    .DESCRIPTION
        Verifies that Docker Model Runner is enabled and can be used
        to run AI models.
    #>
    Write-Log "🔍 Checking Docker Model Runner..." -ForegroundColor $CYAN

    try {
        # Check if Docker Model Runner is available
        $modelRunnerCheck = docker model ls 2>&1

        if ($LASTEXITCODE -ne 0 -or $modelRunnerCheck -match "not enabled") {
            Write-Log "❌ Docker Model Runner is not enabled." -ForegroundColor $RED
            Write-Log "   Please enable Docker Model Runner in Docker Desktop settings:" -ForegroundColor $YELLOW
            Write-Log "   Settings > Features in development > Enable Docker Model Runner" -ForegroundColor $YELLOW
            return $false
        }

        Write-Log "✅ Docker Model Runner is enabled." -ForegroundColor $GREEN

        # List available models
        $availableModels = docker model ls
        Write-Log "   Available models:" -ForegroundColor $CYAN
        Write-Log "$availableModels" -ForegroundColor $CYAN

        return $true
    }
    catch {
        Write-Log "❌ Error checking Docker Model Runner: $_" -ForegroundColor $RED
        return $false
    }
}

function Test-SwarmOverlayNetworking {
    <#
    .SYNOPSIS
        Tests Docker Swarm overlay networking capabilities.
    .DESCRIPTION
        Verifies that Docker Swarm is active and can create overlay networks
        needed for distributed AI workloads.
    #>
    Write-Log "🔍 Checking Docker Swarm networking..." -ForegroundColor $CYAN

    try {
        # Check if Docker Swarm is active
        $swarmStatus = docker info --format '{{.Swarm.LocalNodeState}}'

        if ($swarmStatus -ne "active") {
            Write-Log "❌ Docker Swarm is not active." -ForegroundColor $RED
            Write-Log "   Please initialize Docker Swarm with 'docker swarm init'" -ForegroundColor $YELLOW
            return $false
        }

        # Try to create a test overlay network
        $networkName = "test-overlay-$(Get-Random)"
        docker network create --driver overlay $networkName

        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ Failed to create overlay network. Exit code: $LASTEXITCODE" -ForegroundColor $RED
            return $false
        }

        # Clean up the test network
        docker network rm $networkName

        Write-Log "✅ Docker Swarm overlay networking is configured correctly." -ForegroundColor $GREEN
        return $true
    }
    catch {
        Write-Log "❌ Error checking Docker Swarm networking: $_" -ForegroundColor $RED
        return $false
    }
}

function Test-Performance {
    <#
    .SYNOPSIS
        Tests GPU performance for AI workloads.
    .DESCRIPTION
        Runs a simple GPU performance test to evaluate if the GPU
        is capable of running AI inference workloads efficiently.
    #>
    Write-Log "🔍 Testing GPU performance..." -ForegroundColor $CYAN

    try {
        # Define a simple CUDA benchmark container
        $benchmarkOutput = docker run --rm --gpus all nvcr.io/nvidia/k8s/cuda-sample:nbody -benchmark -numbodies=256000

        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ GPU performance test failed. Exit code: $LASTEXITCODE" -ForegroundColor $RED
            return $false
        }

        # Extract performance numbers
        if ($benchmarkOutput -match "CUDA Bandwidth: ([0-9.]+) GB/s") {
            $bandwidth = $matches[1]
        }
        else {
            $bandwidth = "Unknown"
        }

        Write-Log "✅ GPU performance test completed successfully." -ForegroundColor $GREEN
        Write-Log "   CUDA Bandwidth: $bandwidth GB/s" -ForegroundColor $CYAN

        # Provide performance assessment
        if ([double]$bandwidth -gt 200) {
            Write-Log "   Performance assessment: Excellent ⭐⭐⭐" -ForegroundColor $GREEN
        }
        elseif ([double]$bandwidth -gt 100) {
            Write-Log "   Performance assessment: Good ⭐⭐" -ForegroundColor $GREEN
        }
        else {
            Write-Log "   Performance assessment: Adequate ⭐" -ForegroundColor $YELLOW
        }

        return $true
    }
    catch {
        Write-Log "❌ Error during GPU performance test: $_" -ForegroundColor $RED
        return $false
    }
}

# Main execution
Write-Log "🚀 Starting GPU capabilities test..." -ForegroundColor $CYAN

$results = @{
    "NVIDIA Drivers" = Test-NvidiaDrivers
    "Docker GPU Runtime" = Test-DockerGPURuntime
    "Docker Model Runner" = Test-DockerModelRunner
    "Swarm Overlay Networking" = Test-SwarmOverlayNetworking
}

# Only run performance test if all other tests pass
if (-not $results.Values.Contains($false)) {
    $results["GPU Performance"] = Test-Performance
}

# Overall assessment
Write-Log "`n📊 GPU Capabilities Test Results:" -ForegroundColor $CYAN
$results.GetEnumerator() | ForEach-Object {
    $status = if ($_.Value) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($_.Value) { $GREEN } else { $RED }
    Write-Log "   $($_.Key): $status" -ForegroundColor $color
}

$overallSuccess = -not $results.Values.Contains($false)
if ($overallSuccess) {
    Write-Log "`n✅ All GPU capability tests passed! Your system is ready for AI model inference." -ForegroundColor $GREEN
}
else {
    Write-Log "`n❌ Some GPU capability tests failed. Please address the issues before proceeding." -ForegroundColor $RED
}

return $overallSuccess