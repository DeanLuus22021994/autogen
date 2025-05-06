# Setup-DockerModelRunner.ps1
# Sets up Docker Model Runner with required models

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$CheckOnly = $false,

    [Parameter()]
    [ValidateSet("ai/mistral", "ai/mistral-nemo", "ai/mxbai-embed-large", "ai/smollm2")]
    [string[]]$Models = @("ai/mistral")
)

$ErrorActionPreference = 'Stop'
$GREEN = [ConsoleColor]::Green
$YELLOW = [ConsoleColor]::Yellow
$RED = [ConsoleColor]::Red
$CYAN = [ConsoleColor]::Cyan
$WHITE = [ConsoleColor]::White

Write-Host "🐳 Docker Model Runner Setup and Verification" -ForegroundColor $CYAN

# Check Docker installation
try {
    $dockerVersion = docker --version
    if ($dockerVersion -match 'version (\d+\.\d+\.\d+)') {
        $version = $matches[1]
        Write-Host "✅ Found Docker version: $version" -ForegroundColor $GREEN

        # Check if version meets requirements
        $dockerVersionObj = [Version]$version
        $requiredVersionObj = [Version]"4.40.0"

        if ($dockerVersionObj -lt $requiredVersionObj) {
            Write-Host "❌ Docker version is less than 4.40.0" -ForegroundColor $RED
            Write-Host "   Docker Model Runner requires Docker Desktop 4.40+." -ForegroundColor $RED
            Write-Host "   Please upgrade Docker Desktop to use Docker Model Runner." -ForegroundColor $RED
            exit 1
        }
    } else {
        Write-Host "⚠️ Could not determine Docker version." -ForegroundColor $YELLOW
    }
} catch {
    Write-Host "❌ Docker is not installed or not in PATH." -ForegroundColor $RED
    Write-Host "   Please install Docker Desktop 4.40+ before continuing." -ForegroundColor $RED
    exit 1
}

# Check Docker Model Runner
Write-Host "`n🔍 Checking Docker Model Runner configuration..." -ForegroundColor $CYAN
try {
    # Try to access the model runner endpoint
    $modelRunnerEndpoint = "http://model-runner.docker.internal/engines"
    $response = Invoke-WebRequest -Uri $modelRunnerEndpoint -UseBasicParsing -ErrorAction SilentlyContinue

    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Docker Model Runner is available and responding!" -ForegroundColor $GREEN

        # Parse the JSON response to get available models
        $availableModels = $response.Content | ConvertFrom-Json

        Write-Host "📋 Available models:" -ForegroundColor $CYAN
        foreach ($model in $availableModels) {
            Write-Host "   - $model" -ForegroundColor $WHITE
        }
    }
} catch {
    Write-Host "❌ Docker Model Runner endpoint is not accessible." -ForegroundColor $RED
    Write-Host "   Please ensure Docker Desktop is running with Model Runner enabled:" -ForegroundColor $RED
    Write-Host "   1. Open Docker Desktop" -ForegroundColor $WHITE
    Write-Host "   2. Go to Settings > Features in development > Beta" -ForegroundColor $WHITE
    Write-Host "   3. Enable 'Docker Model Runner'" -ForegroundColor $WHITE
    Write-Host "   4. Click 'Apply & restart'" -ForegroundColor $WHITE
    exit 1
}

# If we're only checking, exit here
if ($CheckOnly) {
    Write-Host "`n✅ Docker Model Runner verification completed successfully!" -ForegroundColor $GREEN
    exit 0
}

# Pull required models
Write-Host "`n🔄 Pulling required models..." -ForegroundColor $CYAN

foreach ($model in $Models) {
    Write-Host "   Pulling model: $model" -ForegroundColor $WHITE
    try {
        docker model pull $model
        Write-Host "   ✅ Successfully pulled model: $model" -ForegroundColor $GREEN
    } catch {
        Write-Host "   ❌ Failed to pull model: $model" -ForegroundColor $RED
        Write-Host "      Error: $_" -ForegroundColor $RED
    }
}

# Check if AutoGen extensions for Docker are installed
Write-Host "`n🔍 Checking AutoGen Docker extensions..." -ForegroundColor $CYAN
$extensionsDir = Join-Path $PSScriptRoot "autogen_extensions\docker"

if (Test-Path $extensionsDir) {
    Write-Host "✅ AutoGen Docker extensions found at: $extensionsDir" -ForegroundColor $GREEN

    # Run the integration test
    Write-Host "`n🧪 Running Docker Model Runner integration test..." -ForegroundColor $CYAN
    try {
        Set-Location $extensionsDir
        python integration_test.py --verbose
        Write-Host "✅ Integration test completed successfully!" -ForegroundColor $GREEN
    } catch {
        Write-Host "⚠️ Integration test failed: $_" -ForegroundColor $YELLOW
        Write-Host "   Please check the Docker Model Runner configuration." -ForegroundColor $YELLOW
    }
} else {
    Write-Host "⚠️ AutoGen Docker extensions not found." -ForegroundColor $YELLOW
    Write-Host "   Expected location: $extensionsDir" -ForegroundColor $YELLOW
}

# SUCCESS!
Write-Host "`n✅ Docker Model Runner setup completed successfully!" -ForegroundColor $GREEN
Write-Host "   You can now use Docker Model Runner with AutoGen." -ForegroundColor $GREEN
Write-Host "   For usage examples, see: autogen_extensions/docker/README.md" -ForegroundColor $CYAN
