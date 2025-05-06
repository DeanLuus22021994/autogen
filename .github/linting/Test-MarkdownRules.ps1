<#
.SYNOPSIS
    Tests markdown rules against the repository.
.DESCRIPTION
    This script builds and runs Docker containers for testing markdown rules
    with configurable options for detailed output and different testing modes.
.PARAMETER BuildContainer
    Switch to build the Docker container only.
.PARAMETER Detailed
    Switch to enable detailed output of rule validation.
.PARAMETER SkipDocker
    Switch to skip Docker and run tests directly on the host.
.EXAMPLE
    .\Test-MarkdownRules.ps1 -BuildContainer
    Builds the Docker container for markdown rule testing.
.EXAMPLE
    .\Test-MarkdownRules.ps1 -Detailed
    Runs tests with detailed output.
#>
[CmdletBinding()]
param (
    [switch]$BuildContainer,
    [switch]$Detailed,
    [switch]$SkipDocker
)

# Azure PowerShell best practices
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue" # Speeds up operations

# Constants
$DOCKER_IMAGE_NAME = "autogen-markdown-rules-tester"
$RULES_DIR = Join-Path $PSScriptRoot "rules"
$TEST_RESULTS_DIR = Join-Path $PSScriptRoot "test-results"

Write-Host "Markdown Rules Testing Tool" -ForegroundColor Cyan
Write-Host "----------------------------" -ForegroundColor Cyan

# Ensure test results directory exists
if (-not (Test-Path $TEST_RESULTS_DIR)) {
    New-Item -Path $TEST_RESULTS_DIR -ItemType Directory -Force | Out-Null
}

function Build-DockerImage {
    Write-Host "Building Docker image for markdown rule testing..." -ForegroundColor Yellow

    $dockerfilePath = Join-Path $PSScriptRoot "dockerfile"

    if (-not (Test-Path $dockerfilePath)) {
        Write-Error "Dockerfile not found at: $dockerfilePath"
        exit 1
    }

    # Using modern Docker build command with buildx for cross-platform compatibility
    docker buildx build --load -t $DOCKER_IMAGE_NAME -f $dockerfilePath $PSScriptRoot

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker build failed with exit code: $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    Write-Host "Docker image built successfully: $DOCKER_IMAGE_NAME" -ForegroundColor Green
}

function Run-RuleTests {
    param (
        [switch]$Detailed
    )

    Write-Host "Running markdown rule tests..." -ForegroundColor Yellow

    $detailedFlag = if ($Detailed) { "--detailed" } else { "" }

    if ($SkipDocker) {
        Write-Host "Running tests directly on host..." -ForegroundColor Magenta
        # Install dependencies if needed
        npm install --prefix $PSScriptRoot

        # Run the tests
        node $PSScriptRoot/run-tests.js $detailedFlag

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Tests failed with exit code: $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    }
    else {
        Write-Host "Running tests in Docker container..." -ForegroundColor Magenta

        # Map repository root as volume in container with read-only flag for security
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot ".." "..")
        $containerResultsDir = "/app/test-results"

        docker run --rm `
            -v "${repoRoot}:/repo:ro" `
            -v "${TEST_RESULTS_DIR}:${containerResultsDir}" `
            -w /app `
            $DOCKER_IMAGE_NAME `
            node run-tests.js $detailedFlag

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Docker run failed with exit code: $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    }

    Write-Host "Markdown rule tests completed successfully" -ForegroundColor Green
}

# Main execution
if ($BuildContainer) {
    Build-DockerImage
}
else {
    # Build container if not skipping Docker and the image doesn't exist
    if (-not $SkipDocker) {
        $imageExists = docker images -q $DOCKER_IMAGE_NAME 2>$null
        if (-not $imageExists) {
            Write-Host "Docker image not found, building first..." -ForegroundColor Yellow
            Build-DockerImage
        }
    }

    Run-RuleTests -Detailed:$Detailed
}

Write-Host "Operation completed successfully" -ForegroundColor Green