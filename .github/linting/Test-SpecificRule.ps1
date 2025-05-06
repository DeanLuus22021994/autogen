<#
.SYNOPSIS
    Tests a specific markdown rule.
.DESCRIPTION
    This script tests a specific markdown rule from the rules directory
    with options for Docker execution and different testing modes.
.PARAMETER RuleName
    The name of the rule to test (without .js extension).
.PARAMETER UseDocker
    Switch to run tests in a Docker container instead of directly on the host.
.PARAMETER Verbose
    Switch to enable verbose output during rule testing.
.EXAMPLE
    .\Test-SpecificRule.ps1 -RuleName "no-trailing-spaces" -UseDocker
    Tests the no-trailing-spaces rule using Docker.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$RuleName,

    [switch]$UseDocker,

    [switch]$Verbose
)

# Azure PowerShell best practices
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue" # Speeds up operations

# Constants
$DOCKER_IMAGE_NAME = "autogen-markdown-rules-tester"
$RULES_DIR = Join-Path $PSScriptRoot "rules"
$TEST_RESULTS_DIR = Join-Path $PSScriptRoot "test-results"

Write-Host "Testing Specific Markdown Rule: $RuleName" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan

# Validate rule exists
$rulePath = Join-Path $RULES_DIR "$RuleName.js"
if (-not (Test-Path $rulePath)) {
    Write-Error "Rule file not found: $rulePath"
    exit 1
}

# Ensure test results directory exists
if (-not (Test-Path $TEST_RESULTS_DIR)) {
    New-Item -Path $TEST_RESULTS_DIR -ItemType Directory -Force | Out-Null
}

function Run-RuleTest {
    param (
        [string]$RuleName,
        [switch]$Verbose
    )

    $verboseFlag = if ($Verbose) { "--verbose" } else { "" }

    if ($UseDocker) {
        Write-Host "Running test in Docker container..." -ForegroundColor Magenta

        # Check if Docker image exists
        $imageExists = docker images -q $DOCKER_IMAGE_NAME 2>$null
        if (-not $imageExists) {
            Write-Host "Docker image not found, building first..." -ForegroundColor Yellow
            & "$PSScriptRoot/Test-MarkdownRules.ps1" -BuildContainer

            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to build Docker image"
                exit $LASTEXITCODE
            }
        }

        # Map repository root as volume in container with read-only flag for security
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot ".." "..")
        $containerResultsDir = "/app/test-results"

        docker run --rm `
            -v "${repoRoot}:/repo:ro" `
            -v "${TEST_RESULTS_DIR}:${containerResultsDir}" `
            -w /app `
            $DOCKER_IMAGE_NAME `
            node test-rule.js --rule=$RuleName $verboseFlag

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Rule test failed with exit code: $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    }
    else {
        Write-Host "Running test directly on host..." -ForegroundColor Magenta

        # Install dependencies if needed
        npm install --prefix $PSScriptRoot

        # Run the specific rule test
        node $PSScriptRoot/test-rule.js --rule=$RuleName $verboseFlag

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Rule test failed with exit code: $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    }

    Write-Host "Rule test completed successfully" -ForegroundColor Green
}

# Main execution
Run-RuleTest -RuleName $RuleName -Verbose:$Verbose

Write-Host "Operation completed successfully" -ForegroundColor Green