# Initialize-MistralGPURunner.ps1
<#
.SYNOPSIS
    Initializes the Mistral GPU model runner for Docker Swarm.

.DESCRIPTION
    This script initializes and configures the Mistral GPU model runner for use with Docker Swarm.
    It verifies NVIDIA GPU support, initializes Docker Swarm if not active, and sets up
    the Mistral model for inference.

.PARAMETER GpuCount
    The number of GPUs to use for the model. Default is 1.

.PARAMETER TensorParallelSize
    The tensor parallel size for model inference. Default is 1.

.PARAMETER Verbose
    When specified, provides more detailed output during operation.

.EXAMPLE
    .\Initialize-MistralGPURunner.ps1

.EXAMPLE
    .\Initialize-MistralGPURunner.ps1 -GpuCount 2 -TensorParallelSize 2
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$GpuCount = 1,

    [Parameter(Mandatory = $false)]
    [int]$TensorParallelSize = 1,

    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# Console colors for better readability
$CYAN = "Cyan"
$GREEN = "Green"
$YELLOW = "Yellow"
$RED = "Red"

# Execution directory tracking
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)

# Load DIR.TAG properties
$dirTagPath = Join-Path -Path (Split-Path -Parent $scriptDir) -ChildPath "DIR.TAG"
$dirTagExists = Test-Path -Path $dirTagPath

if ($dirTagExists) {
    try {
        $dirTagContent = Get-Content -Path $dirTagPath -Raw
        # Extract the status and description from DIR.TAG
        if ($dirTagContent -match 'status:\s*(.+)') {
            $status = $matches[1].Trim()
        }
        if ($dirTagContent -match 'description:\s*\|\s*(.+)') {
            $description = $matches[1].Trim()
        }
    }
    catch {
        Write-Warning "Error reading DIR.TAG file: $_"
    }
}

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

function Test-DockerInstallation {
    <#
    .SYNOPSIS
        Tests if Docker is installed and running.
    .DESCRIPTION
        Verifies that Docker is installed and the service is running by checking
        the Docker CLI and attempting to run a simple Docker command.
    #>
    Write-Log "🔍 Checking Docker installation..." -ForegroundColor $CYAN

    try {
        $dockerVersion = docker version --format '{{.Server.Version}}'
        if ($LASTEXITCODE -ne 0) {
            throw "Docker command failed. Exit code: $LASTEXITCODE"
        }
        Write-Log "✅ Docker is installed (version: $dockerVersion)" -ForegroundColor $GREEN
        return $true
    }
    catch {
        Write-Log "❌ Docker is not installed or not running. Error: $_" -ForegroundColor $RED
        Write-Log "   Please install Docker Desktop from https://www.docker.com/products/docker-desktop/" -ForegroundColor $YELLOW
        return $false
    }
}

function Test-GPUSupport {
    <#
    .SYNOPSIS
        Tests if NVIDIA GPU support is available and properly configured.
    .DESCRIPTION
        Verifies NVIDIA GPU support by running a test container that uses nvidia-smi.
        Returns true if GPU support is available, false otherwise.
    #>
    Write-Log "🔍 Checking NVIDIA GPU support..." -ForegroundColor $CYAN

    try {
        # Test GPU support by running nvidia-smi in a container
        $gpuCheck = docker run --rm --gpus all nvidia/cuda:12.0.1-base-ubuntu22.04 nvidia-smi

        if ($LASTEXITCODE -eq 0) {
            Write-Log "✅ NVIDIA GPU support is configured correctly." -ForegroundColor $GREEN
            Write-Log "GPU Information:" -ForegroundColor $CYAN
            Write-Log "$gpuCheck" -ForegroundColor $CYAN
            return $true
        }
        else {
            Write-Log "❌ NVIDIA GPU test failed with exit code: $LASTEXITCODE" -ForegroundColor $RED
            return $false
        }
    }
    catch {
        Write-Log "❌ NVIDIA GPU support is not configured. Error: $_" -ForegroundColor $RED
        Write-Log "   Please ensure NVIDIA drivers are installed and Docker GPU runtime is enabled." -ForegroundColor $YELLOW
        Write-Log "   See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html" -ForegroundColor $YELLOW
        return $false
    }
}

function Initialize-DockerSwarm {
    <#
    .SYNOPSIS
        Initializes Docker Swarm if it's not already active.
    .DESCRIPTION
        Checks if Docker Swarm is already initialized. If not, initializes a new swarm.
        Returns true if swarm is active (either already or after initialization), false otherwise.
    #>
    Write-Log "🔍 Checking Docker Swarm status..." -ForegroundColor $CYAN

    try {
        $swarmStatus = docker info --format '{{.Swarm.LocalNodeState}}'

        if ($swarmStatus -ne "active") {
            Write-Log "🔄 Initializing Docker Swarm..." -ForegroundColor $YELLOW
            $initCommand = "docker swarm init"
            Invoke-Expression $initCommand

            if ($LASTEXITCODE -ne 0) {
                Write-Log "❌ Failed to initialize Docker Swarm. Exit code: $LASTEXITCODE" -ForegroundColor $RED
                return $false
            }

            Write-Log "✅ Docker Swarm initialized successfully." -ForegroundColor $GREEN
        }
        else {
            Write-Log "✅ Docker Swarm is already active." -ForegroundColor $GREEN
        }

        return $true
    }
    catch {
        Write-Log "❌ Error checking or initializing Docker Swarm: $_" -ForegroundColor $RED
        return $false
    }
}

function Initialize-MistralModel {
    <#
    .SYNOPSIS
        Initializes the Mistral GPU model for inference.
    .DESCRIPTION
        Pulls the Mistral model image, configures it, and prepares it for inference
        using Docker Model Runner.
    .PARAMETER GpuCount
        The number of GPUs to allocate for the model.
    .PARAMETER TensorParallelSize
        The tensor parallel size for model inference.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$GpuCount,

        [Parameter(Mandatory = $true)]
        [int]$TensorParallelSize
    )

    Write-Log "🚀 Initializing Mistral GPU model..." -ForegroundColor $CYAN

    try {
        # Check if Docker Model Runner is available
        $modelRunnerCheck = docker model ls 2>&1
        if ($LASTEXITCODE -ne 0 -or $modelRunnerCheck -match "not enabled") {
            Write-Log "❌ Docker Model Runner is not enabled. Please enable it in Docker Desktop settings." -ForegroundColor $RED
            Write-Log "   Go to Docker Desktop > Settings > Features in development > Enable Docker Model Runner" -ForegroundColor $YELLOW
            return $false
        }

        # Pull the Mistral model
        Write-Log "📥 Pulling Mistral model (this may take a while)..." -ForegroundColor $YELLOW
        docker model pull ai/mistral-nemo

        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ Failed to pull Mistral model. Exit code: $LASTEXITCODE" -ForegroundColor $RED
            return $false
        }

        # Configure model settings
        Write-Log "⚙️ Configuring Mistral model with $GpuCount GPU(s) and tensor parallel size $TensorParallelSize..." -ForegroundColor $CYAN

        # Create necessary overlay networks for Docker Swarm
        docker network create --driver overlay mistral-network

        # Create and configure the Mistral service
        $mistralService = docker service create `
            --name mistral-inference `
            --network mistral-network `
            --publish 8000:8000 `
            --constraint 'node.role==manager' `
            --limit-gpu $GpuCount `
            --label ai.model=mistral-nemo `
            --env GPU_COUNT=$GpuCount `
            --env TENSOR_PARALLEL_SIZE=$TensorParallelSize `
            --endpoint-mode vip `
            --mode replicated `
            --replicas 1 `
            nvcr.io/nvidia/nemo-fw:24.02.01

        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ Failed to create Mistral service. Exit code: $LASTEXITCODE" -ForegroundColor $RED
            return $false
        }

        # Wait for service to become available
        Write-Log "⏳ Waiting for Mistral service to initialize (this may take several minutes)..." -ForegroundColor $YELLOW
        $attempts = 0
        $maxAttempts = 20
        $success = $false

        while ($attempts -lt $maxAttempts -and -not $success) {
            $attempts++
            Write-Log "   Checking service status (attempt $attempts/$maxAttempts)..." -ForegroundColor $CYAN -NoNewline
            $serviceStatus = docker service ps mistral-inference --format '{{.CurrentState}}' | Select-Object -First 1

            if ($serviceStatus -match "Running") {
                Write-Log " Running!" -ForegroundColor $GREEN
                Start-Sleep -Seconds 10  # Give a bit more time for the model to initialize
                $success = $true
            }
            else {
                Write-Log " $serviceStatus" -ForegroundColor $YELLOW
                Start-Sleep -Seconds 15
            }
        }

        if ($success) {
            Write-Log "✅ Mistral GPU model initialized successfully!" -ForegroundColor $GREEN
            Write-Log "   Model is available for inference at http://localhost:8000" -ForegroundColor $CYAN
            return $true
        }
        else {
            Write-Log "❌ Mistral service initialization timed out. Check 'docker service logs mistral-inference' for details." -ForegroundColor $RED
            return $false
        }
    }
    catch {
        Write-Log "❌ Error initializing Mistral model: $_" -ForegroundColor $RED
        return $false
    }
}

# Main execution
Write-Log "🔧 Starting Mistral GPU Runner initialization..." -ForegroundColor $CYAN
Write-Log "   GPU Count: $GpuCount" -ForegroundColor $CYAN
Write-Log "   Tensor Parallel Size: $TensorParallelSize" -ForegroundColor $CYAN

# Check Docker installation
if (-not (Test-DockerInstallation)) {
    exit 1
}

# Initialize Docker Swarm if needed
if (-not (Initialize-DockerSwarm)) {
    Write-Log "❌ Failed to initialize Docker Swarm. Exiting." -ForegroundColor $RED
    exit 1
}

# Check GPU support
$gpuSupport = Test-GPUSupport
if (-not $gpuSupport) {
    Write-Log "❌ NVIDIA GPU support is required for Mistral GPU Runner. Exiting." -ForegroundColor $RED
    exit 1
}

# Initialize Mistral model
if (-not (Initialize-MistralModel -GpuCount $GpuCount -TensorParallelSize $TensorParallelSize)) {
    Write-Log "❌ Failed to initialize Mistral model. Exiting." -ForegroundColor $RED
    exit 1
}

Write-Log "✅ Mistral GPU Runner initialization completed successfully!" -ForegroundColor $GREEN
Write-Log "   Use 'docker service logs mistral-inference' to view model logs." -ForegroundColor $CYAN
Write-Log "   Use 'docker service rm mistral-inference' to stop the service." -ForegroundColor $CYAN
