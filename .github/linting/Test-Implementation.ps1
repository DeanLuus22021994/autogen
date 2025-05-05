# Test-Implementation.ps1
# Test script for markdown linting implementation
# This script will verify that the Docker-based rule testing system works as expected

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

Write-Host "🧪 Testing Markdown Linting Implementation" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor DarkCyan

# Get repository root
try {
    $repoRoot = git rev-parse --show-toplevel
    Set-Location $repoRoot
}
catch {
    Write-Error "❌ Failed to navigate to repository root: $_"
    exit 1
}

# Check if required directories exist
$lintingDir = ".github\linting"
$dockerDir = "$lintingDir\docker"
$examplesDir = "$lintingDir\examples"
$rulesDir = "$lintingDir\rules"

$requiredDirs = @($lintingDir, $dockerDir, $examplesDir, $rulesDir)

foreach ($dir in $requiredDirs) {
    if (-not (Test-Path -Path $dir -PathType Container)) {
        Write-Error "❌ Missing directory: $dir"
        exit 1
    }
    else {
        Write-Host "✅ Found directory: $dir" -ForegroundColor Green
    }
}

# Check if required files exist
$dockerFile = "$dockerDir\Dockerfile"
$runTestsScript = "$dockerDir\run-tests.sh"
$testScript = "$lintingDir\Test-MarkdownRules.ps1"
$specificRuleScript = "$lintingDir\Test-SpecificRule.ps1"
$configFile = "$lintingDir\.markdownlint-cli2.jsonc"
$exampleFile = "$examplesDir\test-example.md"
$sampleRule = "$rulesDir\sample-rule.js"

$requiredFiles = @($dockerFile, $runTestsScript, $testScript, $specificRuleScript, $configFile, $exampleFile)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path -Path $file -PathType Leaf)) {
        Write-Error "❌ Missing file: $file"
        exit 1
    }
    else {
        Write-Host "✅ Found file: $file" -ForegroundColor Green
    }
}

# Function to check if Node.js is installed
function Test-NodeJsAvailable {
    try {
        $nodeVersion = & node --version 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Function to check if markdownlint-cli2 is installed
function Test-MarkdownlintInstalled {
    try {
        $lintVersion = & markdownlint-cli2 --version 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Check if Docker is available
try {
    $dockerVersion = docker --version 2>&1
    Write-Host "✅ Docker command available: $dockerVersion" -ForegroundColor Green

    # Check if Docker daemon is actually working
    try {
        $null = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Docker daemon is responding" -ForegroundColor Green
            $dockerWorking = $true
        }
        else {
            Write-Host "⚠️ Docker daemon is not responding" -ForegroundColor Yellow
            Write-Host "   This could be due to Docker Desktop not running or connection issues" -ForegroundColor Yellow
            Write-Host "   Falling back to local testing..." -ForegroundColor Yellow
            $dockerWorking = $false
        }
    }
    catch {
        Write-Host "⚠️ Docker daemon is not responding: $_" -ForegroundColor Yellow
        Write-Host "   Falling back to local testing..." -ForegroundColor Yellow
        $dockerWorking = $false
    }
}
catch {
    Write-Host "⚠️ Docker is not installed or not in PATH" -ForegroundColor Yellow
    Write-Host "   Falling back to local testing..." -ForegroundColor Yellow
    $dockerWorking = $false
}

# Check if we can do local testing
if (-not $dockerWorking) {
    if (Test-NodeJsAvailable) {
        Write-Host "✅ Node.js is available for local testing" -ForegroundColor Green
        $nodeJsAvailable = $true

        if (Test-MarkdownlintInstalled) {
            Write-Host "✅ markdownlint-cli2 is installed" -ForegroundColor Green
        }
        else {
            Write-Host "⚠️ markdownlint-cli2 is not installed, will attempt to install it" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⚠️ Node.js is not available, local testing may fail" -ForegroundColor Yellow
        $nodeJsAvailable = $false
    }
}

# Exit if Docker is not working
if (-not $dockerWorking) {
    Write-Error "❌ Docker is not working correctly, please fix the issues above"
    exit 1
}

# Build the Docker container if Docker is working
if ($dockerWorking) {
    Write-Host "`n📦 Building Docker container for markdown linting..." -ForegroundColor Cyan
    try {
        Push-Location $dockerDir
        docker build -t autogen-markdown-lint -f $dockerFile .
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to build Docker container, falling back to local testing..."
            $dockerWorking = $false
        }
        else {
            Write-Host "✅ Docker container built successfully" -ForegroundColor Green
        }
        Pop-Location
    }
    catch {
        Write-Warning "Error building Docker container: $_"
        Write-Host "⚠️ Falling back to local testing..." -ForegroundColor Yellow
        $dockerWorking = $false
        if ($null -ne (Get-Location).Path) {
            Pop-Location
        }
    }
}
else {
    Write-Host "`n⚠️ Docker is not working, using local testing..." -ForegroundColor Yellow
}

# Test the rule execution
Write-Host "`n🔍 Testing markdown rule execution..." -ForegroundColor Cyan
try {
    $testParams = @{
        Path = $examplesDir
        RulesDirectory = $rulesDir
        ConfigFile = $configFile
    }

    if ($dockerWorking) {
        $testParams.Add("BuildContainer", $false) # We already built it
    }
    else {
        $testParams.Add("Local", $true) # Fall back to local execution
    }

    if ($Detailed) {
        $testParams.Add("Detailed", $true)
    }

    & $testScript @testParams

    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ Rule testing failed"
        exit 1
    }
    else {
        Write-Host "✅ Rule testing successful" -ForegroundColor Green
    }
}
catch {
    Write-Error "❌ Error during rule testing: $_"
    exit 1
}

# Test specific rule
if (Test-Path -Path $sampleRule -PathType Leaf) {
    Write-Host "`n🔍 Testing specific rule execution..." -ForegroundColor Cyan
    try {
        $ruleParams = @{
            RuleName = "sample-rule"
        }

        if ($dockerWorking) {
            $ruleParams.Add("UseDocker", $true)
        }
        else {
            Write-Host "⚠️ Docker not working, falling back to local execution" -ForegroundColor Yellow
        }

        if ($Detailed) {
            $ruleParams.Add("Verbose", $true)
        }

        & $specificRuleScript @ruleParams

        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Specific rule testing failed"
            exit 1
        }
        else {
            Write-Host "✅ Specific rule testing successful" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "❌ Error during specific rule testing: $_"
        exit 1
    }
}
else {
    Write-Host "⚠️ Sample rule file not found, skipping specific rule test" -ForegroundColor Yellow
}

Write-Host "`n🎉 Implementation test completed successfully!" -ForegroundColor Green
Write-Host "The Docker-based markdown linting system is working as expected" -ForegroundColor White
exit 0
