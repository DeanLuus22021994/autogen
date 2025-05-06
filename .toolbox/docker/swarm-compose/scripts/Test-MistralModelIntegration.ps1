# Test-MistralModelIntegration.ps1
<#
.SYNOPSIS
    Tests the integration between Docker Swarm Compose and Docker Model Runner for Mistral models.

.DESCRIPTION
    This script tests the integration by checking the availability of Docker Model Runner,
    verifying Mistral models, and testing basic inference functionality.

.PARAMETER Verbose
    Optional. If specified, shows detailed output during the test.

.EXAMPLE
    .\Test-MistralModelIntegration.ps1

.EXAMPLE
    .\Test-MistralModelIntegration.ps1 -Verbose
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$GREEN = [ConsoleColor]::Green
$YELLOW = [ConsoleColor]::Yellow
$RED = [ConsoleColor]::Red
$CYAN = [ConsoleColor]::Cyan
$WHITE = [ConsoleColor]::White

function Write-TestStatus {
    param (
        [string]$TestName,
        [bool]$Success,
        [string]$Message = ""
    )

    if ($Success) {
        Write-Host "✅ $TestName" -ForegroundColor $GREEN
    } else {
        Write-Host "❌ $TestName" -ForegroundColor $RED
    }

    if ($Message -and ($Verbose -or -not $Success)) {
        Write-Host "   $Message" -ForegroundColor $WHITE
    }
}

function Test-DockerRunning {
    try {
        docker info 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Test-ModelRunnerEndpoint {
    try {
        $modelRunnerEndpoint = "http://model-runner.docker.internal/engines"
        $response = Invoke-WebRequest -Uri $modelRunnerEndpoint -UseBasicParsing -ErrorAction SilentlyContinue
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Test-MistralModelsAvailable {
    try {
        $modelRunnerEndpoint = "http://model-runner.docker.internal/engines"
        $response = Invoke-WebRequest -Uri $modelRunnerEndpoint -UseBasicParsing -ErrorAction SilentlyContinue

        if ($response.StatusCode -eq 200) {
            $availableModels = $response.Content | ConvertFrom-Json
            return $availableModels -contains "ai/mistral-nemo" -or $availableModels -contains "ai/mistral"
        }

        return $false
    } catch {
        return $false
    }
}

function Test-ConfigurationFiles {
    $modelIntegrationDir = Join-Path $PSScriptRoot ".."
    $envFilePath = Join-Path $modelIntegrationDir "model-integration\mistral-environment.json"
    $dirTagPath = Join-Path $modelIntegrationDir "model-integration\DIR.TAG"

    $configFilesExist = (Test-Path $envFilePath) -and (Test-Path $dirTagPath)
    return $configFilesExist
}

function Test-BasicInference {
    try {
        $modelRunnerEndpoint = "http://model-runner.docker.internal/engines/v1/chat/completions"

        $requestBody = @{
            model = "ai/mistral"  # Try with standard Mistral first as it's likely to be available
            messages = @(
                @{
                    role = "system"
                    content = "You are a helpful assistant."
                },
                @{
                    role = "user"
                    content = "Hello, how are you? Please keep your response very brief."
                }
            )
            temperature = 0.5
            max_tokens = 50
        }

        $requestJson = $requestBody | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $modelRunnerEndpoint -Method Post -Body $requestJson -ContentType "application/json" -ErrorAction SilentlyContinue

        return $null -ne $response.choices -and $response.choices.Count -gt 0
    } catch {
        if ($Verbose) {
            Write-Host "   Error: $_" -ForegroundColor $RED
        }
        return $false
    }
}

# Main script
try {
    Write-Host "📋 Mistral Model Integration Test" -ForegroundColor $CYAN
    Write-Host "=================================" -ForegroundColor $CYAN

    # Test 1: Docker is running
    $dockerRunning = Test-DockerRunning
    Write-TestStatus -TestName "Docker is running" -Success $dockerRunning -Message "Docker must be running for the integration to work."

    if (-not $dockerRunning) {
        Write-Host "⚠️ Docker is not running. Please start Docker Desktop before continuing." -ForegroundColor $YELLOW
        exit 1
    }

    # Test 2: Docker Model Runner endpoint is accessible
    $modelRunnerAvailable = Test-ModelRunnerEndpoint
    Write-TestStatus -TestName "Docker Model Runner endpoint is accessible" -Success $modelRunnerAvailable -Message "The Model Runner endpoint should be accessible at http://model-runner.docker.internal/engines"

    # Test 3: Mistral models are available
    $mistralModelsAvailable = Test-MistralModelsAvailable
    Write-TestStatus -TestName "Mistral models are available" -Success $mistralModelsAvailable -Message "At least one Mistral model (ai/mistral-nemo or ai/mistral) should be available in Docker Model Runner."

    # Test 4: Configuration files exist
    $configFilesExist = Test-ConfigurationFiles
    Write-TestStatus -TestName "Configuration files exist" -Success $configFilesExist -Message "The mistral-environment.json and DIR.TAG files should exist in the model-integration directory."

    # Test 5: Basic inference works
    $inferenceWorks = $false
    if ($modelRunnerAvailable -and $mistralModelsAvailable) {
        $inferenceWorks = Test-BasicInference
        Write-TestStatus -TestName "Basic inference works" -Success $inferenceWorks -Message "A simple inference request should return a response from the model."
    } else {
        Write-TestStatus -TestName "Basic inference works" -Success $false -Message "Skipped because Docker Model Runner or Mistral models are not available."
    }

    # Summary
    Write-Host "`n📊 Test Summary" -ForegroundColor $CYAN
    Write-Host "=============" -ForegroundColor $CYAN

    $totalTests = 5
    $passedTests = [int]$dockerRunning + [int]$modelRunnerAvailable + [int]$mistralModelsAvailable + [int]$configFilesExist + [int]$inferenceWorks

    Write-Host "Passed: $passedTests/$totalTests tests" -ForegroundColor $(if ($passedTests -eq $totalTests) { $GREEN } elseif ($passedTests -ge 3) { $YELLOW } else { $RED })

    if ($passedTests -eq $totalTests) {
        Write-Host "`n🎉 All tests passed! The Mistral model integration is working correctly." -ForegroundColor $GREEN
    } elseif ($passedTests -ge 3) {
        Write-Host "`n⚠️ Some tests passed, but there are issues with the integration." -ForegroundColor $YELLOW
        Write-Host "Please review the failed tests and fix the issues before using the integration." -ForegroundColor $YELLOW
    } else {
        Write-Host "`n❌ Multiple tests failed. The integration is not working correctly." -ForegroundColor $RED
        Write-Host "Please run the Setup-MistralModelIntegration.ps1 script to set up the integration." -ForegroundColor $RED
    }
} catch {
    Write-Host "❌ Error testing Mistral model integration: $_" -ForegroundColor $RED
    exit 1
}
