<#
.SYNOPSIS
    Tests a specific markdown rule with enhanced Azure and Docker Model Runner support.
.DESCRIPTION
    This script tests a specific markdown rule from the rules directory
    with options for Docker execution and different testing modes.

    Implements Azure PowerShell best practices and supports Docker Model Runner
    for enhanced testing capabilities.
.PARAMETER RuleName
    The name of the rule to test (without .js extension).
.PARAMETER UseDocker
    Switch to run tests in a Docker container instead of directly on the host.
.PARAMETER UseModelRunner
    Switch to utilize Docker Model Runner for enhanced validation if available.
.PARAMETER Verbose
    Switch to enable verbose output during rule testing.
.PARAMETER OutputFormat
    Format for test results output. Supported values: 'Default', 'JSON', 'NUnit'.
.EXAMPLE
    .\Test-SpecificRule.ps1 -RuleName "no-trailing-spaces" -UseDocker
    Tests the no-trailing-spaces rule using Docker.
.EXAMPLE
    .\Test-SpecificRule.ps1 -RuleName "heading-structure" -UseModelRunner -OutputFormat JSON
    Tests the heading-structure rule using Docker Model Runner with JSON output.
.NOTES
    Requires Docker Desktop 4.40+ for Docker Model Runner functionality.
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
$RULES_DIR = Join-Path $PSScriptRoot "rules"
$TEST_RESULTS_DIR = Join-Path $PSScriptRoot "test-results"
$DOCKER_MODEL_RUNNER_ENDPOINT = "http://model-runner.docker.internal/engines/v1/chat/completions"
$TIMESTAMP = Get-Date -Format "yyyyMMdd-HHmmss"
$LOG_FILE = Join-Path $TEST_RESULTS_DIR "rule-test-$RuleName-$TIMESTAMP.log"

# Create a script-scoped variable to track script success
$script:TestSuccessful = $true

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
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to console with appropriate color
    switch ($Level) {
        'Info'    { Write-Host $logMessage -ForegroundColor White }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        'Debug'   { if ($Verbose) { Write-Host $logMessage -ForegroundColor Gray } }
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

function Run-RuleTest {
    param (
        [string]$RuleName,
        [switch]$Verbose,
        [string]$OutputFormat
    )

    $verboseFlag = if ($Verbose) { "--verbose" } else { "" }
    $outputFormatFlag = if ($OutputFormat -ne 'Default') { "--format=$OutputFormat" } else { "" }

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
            $useModelRunnerFlag = ""
            $modelRunnerEndpointFlag = ""
        }
    }
    else {
        $useModelRunnerFlag = ""
        $modelRunnerEndpointFlag = ""
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

        # Check if Docker image exists
        $imageExists = docker images -q $DOCKER_IMAGE_NAME 2>$null
        if (-not $imageExists) {
            Write-Log "Docker image not found, building first..." -Level Info
            try {
                & "$PSScriptRoot/Test-MarkdownRules.ps1" -BuildContainer

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

        # Complete the command with working directory and parameters
        $dockerCommand += "-w /app " +
                         "$DOCKER_IMAGE_NAME " +
                         "node test-rule.js " +
                         "--rule=$RuleName " +
                         "$verboseFlag " +
                         "$outputFormatFlag " +
                         "$useModelRunnerFlag " +
                         "$modelRunnerEndpointFlag"

        Write-Log "Executing: $dockerCommand" -Level Debug

        try {
            # Execute the command
            $output = Invoke-Expression $dockerCommand

            if ($LASTEXITCODE -ne 0) {
                Write-Log "Rule test in Docker failed with exit code: $LASTEXITCODE" -Level Error
                $script:TestSuccessful = $false
                return
            }

            # Export test results
            Export-TestResults -ResultsData $output -Format $OutputFormat -RuleName $RuleName
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
                           "$modelRunnerEndpointFlag"

            Write-Log "Executing: $nodeCommand" -Level Debug

            # Run the specific rule test and capture output
            $output = Invoke-Expression $nodeCommand

            if ($LASTEXITCODE -ne 0) {
                Write-Log "Rule test failed with exit code: $LASTEXITCODE" -Level Error
                $script:TestSuccessful = $false
                return
            }

            # Export test results
            Export-TestResults -ResultsData $output -Format $OutputFormat -RuleName $RuleName
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
Write-Log "Parameters: UseDocker=$UseDocker, UseModelRunner=$UseModelRunner, Verbose=$Verbose, OutputFormat=$OutputFormat" -Level Debug

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