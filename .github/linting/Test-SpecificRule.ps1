<#
.SYNOPSIS
    Tests a specific markdown rule with enhanced Azure integration and GPU acceleration.
.DESCRIPTION
    This script tests a specific markdown rule from the rules directory
    with options for Docker execution and different testing modes.

    Implements Azure PowerShell best practices and supports Docker Model Runner
    with GPU acceleration for enhanced testing capabilities.
.PARAMETER RuleName
    The name of the rule to test (without .js extension).
.PARAMETER UseDocker
    Switch to run tests in a Docker container instead of directly on the host.
.PARAMETER UseModelRunner
    Switch to utilize Docker Model Runner for enhanced validation if available.
.PARAMETER UseGPU
    Switch to enable GPU acceleration for Docker containers if available.
.PARAMETER Verbose
    Switch to enable verbose output during rule testing.
.PARAMETER OutputFormat
    Format for test results output. Supported values: 'Default', 'JSON', 'NUnit'.
.EXAMPLE
    .\Test-SpecificRule.ps1 -RuleName "no-trailing-spaces" -UseDocker
    Tests the no-trailing-spaces rule using Docker.
.EXAMPLE
    .\Test-SpecificRule.ps1 -RuleName "heading-structure" -UseModelRunner -UseGPU -OutputFormat JSON
    Tests the heading-structure rule using Docker Model Runner with GPU acceleration and JSON output.
.NOTES
    Requires Docker Desktop 4.40+ for Docker Model Runner functionality.
    For GPU acceleration, requires NVIDIA driver 525+ and NVIDIA Container Toolkit.
    Azure PowerShell best practices implemented per May 2025 guidelines.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Name of the rule to test (without .js extension)")]
    [string]$RuleName,

    [Parameter(HelpMessage="Run tests in a Docker container")]
    [switch]$UseDocker,

    [Parameter(HelpMessage="Use Docker Model Runner for enhanced testing")]
    [switch]$UseModelRunner,

    [Parameter(HelpMessage="Enable GPU acceleration for Docker containers")]
    [switch]$UseGPU,

    [Parameter(HelpMessage="Enable verbose output during testing")]
    [switch]$Verbose,

    [Parameter(HelpMessage="Format for test results output")]
    [ValidateSet('Default', 'JSON', 'NUnit')]
    [string]$OutputFormat = 'Default'
)

# Azure PowerShell best practices
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue" # Speeds up operations
$InformationPreference = "Continue"      # Shows information stream

# Constants
$DOCKER_IMAGE_NAME = "autogen-markdown-rules-tester"
$DOCKER_GPU_IMAGE_NAME = "autogen-markdown-rules-tester-gpu"
$RULES_DIR = Join-Path $PSScriptRoot "rules"
$TEST_RESULTS_DIR = Join-Path $PSScriptRoot "test-results"
$DOCKER_MODEL_RUNNER_ENDPOINT = "http://model-runner.docker.internal/engines/v1/chat/completions"
$TIMESTAMP = Get-Date -Format "yyyyMMdd-HHmmss"
$LOG_FILE = Join-Path $TEST_RESULTS_DIR "rule-test-$RuleName-$TIMESTAMP.log"
$PERF_FILE = Join-Path $TEST_RESULTS_DIR "perf-test-$RuleName-$TIMESTAMP.json"

# Create a script-scoped variable to track script success
$script:TestSuccessful = $true
$script:StartTime = Get-Date

# Ensure test results directory exists
if (-not (Test-Path $TEST_RESULTS_DIR)) {
    New-Item -Path $TEST_RESULTS_DIR -ItemType Directory -Force | Out-Null
}

# Setup logging
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug', 'Performance')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to console with appropriate color
    switch ($Level) {
        'Info'        { Write-Host $logMessage -ForegroundColor White }
        'Warning'     { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'       { Write-Host $logMessage -ForegroundColor Red }
        'Success'     { Write-Host $logMessage -ForegroundColor Green }
        'Debug'       { if ($Verbose) { Write-Host $logMessage -ForegroundColor Gray } }
        'Performance' { Write-Host $logMessage -ForegroundColor Cyan }
    }

    # Write to log file
    $logMessage | Out-File -FilePath $LOG_FILE -Append
}

function Test-DockerAvailability {
    Write-Log "Checking Docker availability..." -Level Debug

    try {
        $dockerVersion = docker version --format "{{.Server.Version}}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker command failed with exit code: $LASTEXITCODE"
        }

        Write-Log "Docker available (version: $dockerVersion)" -Level Debug
        return $true
    }
    catch {
        Write-Log "Docker is not available or not running: $_" -Level Warning
        return $false
    }
}

function Test-DockerModelRunnerAvailability {
    Write-Log "Checking Docker Model Runner availability..." -Level Debug

    try {
        # Check if Docker Model Runner endpoint is accessible
        $response = Invoke-WebRequest -Uri "http://model-runner.docker.internal/engines" -Method HEAD -TimeoutSec 2 -ErrorAction SilentlyContinue

        if ($response.StatusCode -eq 200) {
            Write-Log "Docker Model Runner is available" -Level Debug
            return $true
        }
    }
    catch {
        Write-Log "Docker Model Runner is not available: $_" -Level Debug
        return $false
    }

    return $false
}

function Test-NvidiaGPUAvailability {
    Write-Log "Checking NVIDIA GPU availability..." -Level Debug

    try {
        # Check if nvidia-smi is available
        $nvidiaSmi = Get-Command "nvidia-smi" -ErrorAction SilentlyContinue

        if ($null -eq $nvidiaSmi) {
            Write-Log "nvidia-smi tool not found on PATH" -Level Warning
            return $false
        }

        # Run nvidia-smi to get GPU information
        $gpuInfo = & nvidia-smi --query-gpu=name,memory.total,utilization.gpu --format=csv,noheader

        if ($LASTEXITCODE -ne 0) {
            Write-Log "nvidia-smi command failed with exit code: $LASTEXITCODE" -Level Warning
            return $false
        }

        # Check for RTX 3060 specifically
        if ($gpuInfo -match "RTX 3060") {
            # Parse GPU utilization
            $utilization = [int]($gpuInfo -replace ".*,\s*(\d+)\s*%.*", '$1')
            $gpuName = ($gpuInfo -split ",")[0].Trim()
            $gpuMemory = ($gpuInfo -split ",")[1].Trim()

            Write-Log "NVIDIA GPU found: $gpuName with $gpuMemory memory, current utilization: $utilization%" -Level Success

            if ($utilization -le 5) {
                Write-Log "GPU is idle and available for compute tasks" -Level Success
                return $true
            }
            else {
                Write-Log "GPU is currently in use (utilization: $utilization%)" -Level Warning
                return $false
            }
        }
        else {
            Write-Log "NVIDIA RTX 3060 GPU not found. Available GPU: $gpuInfo" -Level Warning
            return $true  # Return true but we'll log a warning about not being the expected GPU
        }
    }
    catch {
        Write-Log "Error checking GPU availability: $_" -Level Warning
        return $false
    }
}

function Test-DockerNvidiaSupport {
    Write-Log "Checking Docker NVIDIA support..." -Level Debug

    try {
        # Test if Docker can run with NVIDIA runtime
        $result = docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Docker NVIDIA support is available" -Level Success
            return $true
        }
        else {
            Write-Log "Docker NVIDIA support is not properly configured" -Level Warning
            return $false
        }
    }
    catch {
        Write-Log "Error testing Docker NVIDIA support: $_" -Level Warning
        return $false
    }
}

function Export-TestResults {
    param (
        [string]$ResultsData,
        [string]$Format,
        [string]$RuleName
    )

    $resultsFilePath = Join-Path $TEST_RESULTS_DIR "$RuleName-results-$TIMESTAMP"

    switch ($Format) {
        'JSON' {
            $resultsFilePath += ".json"
            $ResultsData | Out-File -FilePath $resultsFilePath -Encoding utf8
        }
        'NUnit' {
            $resultsFilePath += ".xml"
            $ResultsData | Out-File -FilePath $resultsFilePath -Encoding utf8
        }
        Default {
            $resultsFilePath += ".txt"
            $ResultsData | Out-File -FilePath $resultsFilePath -Encoding utf8
        }
    }

    Write-Log "Test results exported to: $resultsFilePath" -Level Info
    return $resultsFilePath
}

function Export-PerformanceData {
    param (
        [DateTime]$StartTime,
        [DateTime]$EndTime,
        [bool]$UsedGPU,
        [bool]$UsedDocker,
        [bool]$UsedModelRunner,
        [string]$RuleName
    )

    $duration = ($EndTime - $StartTime).TotalSeconds

    $perfData = @{
        RuleName = $RuleName
        StartTime = $StartTime.ToString("o")
        EndTime = $EndTime.ToString("o")
        DurationSeconds = [math]::Round($duration, 3)
        UsedGPU = $UsedGPU
        UsedDocker = $UsedDocker
        UsedModelRunner = $UsedModelRunner
        Environment = @{
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            OS = [System.Environment]::OSVersion.VersionString
        }
    }

    # Add GPU info if used
    if ($UsedGPU) {
        try {
            $gpuInfo = & nvidia-smi --query-gpu=name,memory.total,utilization.gpu --format=csv,noheader
            $gpuName = ($gpuInfo -split ",")[0].Trim()

            $perfData.GPU = @{
                Name = $gpuName
                Info = $gpuInfo
            }
        }
        catch {
            $perfData.GPU = @{
                Name = "Unknown"
                Error = $_.ToString()
            }
        }
    }

    # Convert to JSON
    $jsonPerfData = ConvertTo-Json $perfData -Depth 5

    # Save to file
    $jsonPerfData | Out-File -FilePath $PERF_FILE -Encoding utf8

    Write-Log "Performance data saved to: $PERF_FILE" -Level Performance
    Write-Log "Execution time: $([math]::Round($duration, 2)) seconds" -Level Performance

    if ($UsedGPU) {
        Write-Log "GPU-accelerated execution completed" -Level Performance
    }
}

function Run-RuleTest {
    param (
        [string]$RuleName,
        [switch]$Verbose,
        [string]$OutputFormat
    )

    $verboseFlag = if ($Verbose) { "--verbose" } else { "" }
    $outputFormatFlag = if ($OutputFormat -ne 'Default') { "--format=$OutputFormat" } else { "" }

    # Initialize GPU and Docker Model Runner flags
    $useGPUFlag = ""
    $useModelRunnerFlag = ""
    $modelRunnerEndpointFlag = ""
    $gpuAvailable = $false

    # Check if GPU should be used and is available
    if ($UseGPU) {
        $gpuAvailable = Test-NvidiaGPUAvailability

        if ($gpuAvailable) {
            $dockerNvidiaSupport = Test-DockerNvidiaSupport

            if ($dockerNvidiaSupport) {
                Write-Log "GPU acceleration enabled for this rule test" -Level Success
                $useGPUFlag = "--use-gpu"
            }
            else {
                Write-Log "GPU acceleration requested but Docker NVIDIA support is not properly configured. Falling back to CPU." -Level Warning
                $gpuAvailable = $false
            }
        }
        else {
            Write-Log "GPU acceleration requested but no suitable GPU is available. Falling back to CPU." -Level Warning
        }
    }

    # Check if Docker Model Runner should be used and is available
    if ($UseModelRunner) {
        $modelRunnerAvailable = Test-DockerModelRunnerAvailability

        if ($modelRunnerAvailable) {
            Write-Log "Using Docker Model Runner for enhanced rule testing" -Level Info
            $useModelRunnerFlag = "--use-model-runner"
            $modelRunnerEndpointFlag = "--model-endpoint=$DOCKER_MODEL_RUNNER_ENDPOINT"
        }
        else {
            Write-Log "Docker Model Runner requested but not available. Falling back to standard testing." -Level Warning
        }
    }

    if ($UseDocker) {
        # Check if Docker is available
        $dockerAvailable = Test-DockerAvailability
        if (-not $dockerAvailable) {
            Write-Log "Docker was requested but is not available. Cannot proceed with Docker-based testing." -Level Error
            $script:TestSuccessful = $false
            return
        }

        Write-Log "Running test in Docker container..." -Level Info

        # Determine which Docker image to use based on GPU availability
        $dockerImageToUse = if ($gpuAvailable) { $DOCKER_GPU_IMAGE_NAME } else { $DOCKER_IMAGE_NAME }

        # Check if Docker image exists
        $imageExists = docker images -q $dockerImageToUse 2>$null
        if (-not $imageExists) {
            Write-Log "Docker image '$dockerImageToUse' not found, building first..." -Level Info
            try {
                $dockerfilePath = if ($gpuAvailable) { "docker/Dockerfile.gpu" } else { "dockerfile" }
                & "$PSScriptRoot/Test-MarkdownRules.ps1" -BuildContainer -GPUBuild:$gpuAvailable

                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Failed to build Docker image" -Level Error
                    $script:TestSuccessful = $false
                    return
                }
            }
            catch {
                Write-Log "Exception while building Docker image: $_" -Level Error
                $script:TestSuccessful = $false
                return
            }
        }

        # Map repository root as volume in container with read-only flag for security
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot ".." "..")
        $containerResultsDir = "/app/test-results"

        Write-Log "Starting Docker container for rule testing" -Level Debug

        # Build the Docker run command
        $dockerCommand = "docker run --rm " +
                         "-v `"${repoRoot}:/repo:ro`" " +
                         "-v `"${TEST_RESULTS_DIR}:${containerResultsDir}`" "

        # Add Docker Model Runner networking if needed
        if ($UseModelRunner -and $modelRunnerAvailable) {
            $dockerCommand += "--add-host=model-runner.docker.internal:host-gateway "
        }

        # Add GPU flag if available
        if ($gpuAvailable) {
            $dockerCommand += "--gpus all "
        }

        # Complete the command with working directory and parameters
        $dockerCommand += "-w /app " +
                         "$dockerImageToUse " +
                         "node test-rule.js " +
                         "--rule=$RuleName " +
                         "$verboseFlag " +
                         "$outputFormatFlag " +
                         "$useModelRunnerFlag " +
                         "$modelRunnerEndpointFlag " +
                         "$useGPUFlag"

        Write-Log "Executing: $dockerCommand" -Level Debug

        try {
            # Execute the command and capture the start time
            $startExecTime = Get-Date
            $output = Invoke-Expression $dockerCommand
            $endExecTime = Get-Date

            if ($LASTEXITCODE -ne 0) {
                Write-Log "Rule test in Docker failed with exit code: $LASTEXITCODE" -Level Error
                $script:TestSuccessful = $false
                return
            }

            # Export test results
            Export-TestResults -ResultsData $output -Format $OutputFormat -RuleName $RuleName

            # Export performance data
            Export-PerformanceData -StartTime $startExecTime -EndTime $endExecTime -UsedGPU $gpuAvailable -UsedDocker $true -UsedModelRunner $modelRunnerAvailable -RuleName $RuleName
        }
        catch {
            Write-Log "Exception while running Docker container: $_" -Level Error
            $script:TestSuccessful = $false
            return
        }
    }
    else {
        Write-Log "Running test directly on host..." -Level Info

        try {
            # Install dependencies if needed
            Write-Log "Checking npm dependencies..." -Level Debug
            npm install --prefix $PSScriptRoot

            if ($LASTEXITCODE -ne 0) {
                Write-Log "Failed to install npm dependencies" -Level Error
                $script:TestSuccessful = $false
                return
            }

            # Build the Node.js command
            $nodeCommand = "node $PSScriptRoot/test-rule.js " +
                           "--rule=$RuleName " +
                           "$verboseFlag " +
                           "$outputFormatFlag " +
                           "$useModelRunnerFlag " +
                           "$modelRunnerEndpointFlag " +
                           "$useGPUFlag"

            Write-Log "Executing: $nodeCommand" -Level Debug

            # Run the specific rule test and capture output along with timing
            $startExecTime = Get-Date
            $output = Invoke-Expression $nodeCommand
            $endExecTime = Get-Date

            if ($LASTEXITCODE -ne 0) {
                Write-Log "Rule test failed with exit code: $LASTEXITCODE" -Level Error
                $script:TestSuccessful = $false
                return
            }

            # Export test results
            Export-TestResults -ResultsData $output -Format $OutputFormat -RuleName $RuleName

            # Export performance data
            Export-PerformanceData -StartTime $startExecTime -EndTime $endExecTime -UsedGPU $false -UsedDocker $false -UsedModelRunner $modelRunnerAvailable -RuleName $RuleName
        }
        catch {
            Write-Log "Exception during rule test execution: $_" -Level Error
            $script:TestSuccessful = $false
            return
        }
    }

    Write-Log "Rule test completed successfully" -Level Success
}

# Log script start
Write-Log "=== Testing Markdown Rule: $RuleName ===" -Level Info
Write-Log "Test execution ID: $TIMESTAMP" -Level Debug
Write-Log "Parameters: UseDocker=$UseDocker, UseModelRunner=$UseModelRunner, UseGPU=$UseGPU, Verbose=$Verbose, OutputFormat=$OutputFormat" -Level Debug

# Validate rule exists
$rulePath = Join-Path $RULES_DIR "$RuleName.js"
if (-not (Test-Path $rulePath)) {
    Write-Log "Rule file not found: $rulePath" -Level Error
    exit 1
}

# Main execution
try {
    Run-RuleTest -RuleName $RuleName -Verbose:$Verbose -OutputFormat $OutputFormat

    if ($script:TestSuccessful) {
        Write-Log "Operation completed successfully" -Level Success

        # Calculate total execution time
        $totalDuration = (Get-Date) - $script:StartTime
        Write-Log "Total script execution time: $([math]::Round($totalDuration.TotalSeconds, 2)) seconds" -Level Performance

        exit 0
    }
    else {
        Write-Log "Operation completed with errors" -Level Error
        exit 1
    }
}
catch {
    Write-Log "Unhandled exception: $_" -Level Error
    exit 1
}
finally {
    Write-Log "Test execution completed (Successful=$($script:TestSuccessful))" -Level Info
    Write-Log "Log file: $LOG_FILE" -Level Info
}