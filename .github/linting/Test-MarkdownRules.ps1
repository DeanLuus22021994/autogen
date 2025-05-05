# Test-MarkdownRules.ps1
# Script to test markdown linting rules using Docker with instant startup

<#
.SYNOPSIS
    Tests markdown linting rules in a Docker container with instant startup.

.DESCRIPTION
    This script runs markdown linting rule tests in a Docker container,
    optimized for instant startup. It leverages Docker layer caching and
    volume mounting to provide quick feedback on rule changes.

.PARAMETER Path
    The path to the directory containing markdown files to test.
    Defaults to the repository root.

.PARAMETER RulesDirectory
    The path to the directory containing custom markdown rules.
    Defaults to .github/linting/rules.

.PARAMETER ConfigFile
    The path to the markdown linting configuration file.
    Defaults to .github/linting/.markdownlint-cli2.jsonc.

.PARAMETER BuildContainer
    If specified, rebuilds the Docker container before running tests.

.PARAMETER Local
    If specified, runs the tests locally instead of in a Docker container.

.PARAMETER Detailed
    If specified, shows detailed output from the linting process.

.EXAMPLE
    .\Test-MarkdownRules.ps1
    Tests all markdown files in the repository using default settings.

.EXAMPLE
    .\Test-MarkdownRules.ps1 -Path docs -RulesDirectory custom-rules -BuildContainer
    Tests markdown files in the docs directory using rules from the custom-rules directory
    and rebuilds the Docker container before running tests.

.NOTES
    This script requires Docker to be installed and running on the system.
    For local execution, Node.js and markdownlint-cli2 must be installed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [string]$RulesDirectory,

    [Parameter(Mandatory = $false)]
    [string]$ConfigFile,

    [Parameter(Mandatory = $false)]
    [switch]$BuildContainer,

    [Parameter(Mandatory = $false)]
    [switch]$Local,

    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

# Get the directory of the current script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Set default values if not specified
if (-not $Path) {
    $Path = $repoRoot
}

if (-not $RulesDirectory) {
    $RulesDirectory = Join-Path -Path $scriptPath -ChildPath "rules"
}

if (-not $ConfigFile) {
    $ConfigFile = Join-Path -Path $scriptPath -ChildPath ".markdownlint-cli2.jsonc"
}

# Docker image name
$dockerImageName = "autogen-markdown-lint"
$dockerfilePath = Join-Path -Path $scriptPath -ChildPath "docker/Dockerfile"
$dockerRunScriptPath = Join-Path -Path $scriptPath -ChildPath "docker/run-tests.sh"

# Check if Docker is available and working
function Test-DockerAvailable {
    try {
        # First check if Docker command exists
        $null = & docker --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        # Then check if Docker daemon is responding
        $null = & docker info 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Build Docker container if requested or if it doesn't exist
function Build-DockerContainer {
    $dockerBuildPath = Split-Path -Parent $dockerfilePath
    Write-Host "🔨 Building Docker container for markdown linting..." -ForegroundColor Cyan

    # Check if the Docker image already exists
    $imageExists = $false
    try {
        $imageInfo = & docker images --format "{{.Repository}}" | Where-Object { $_ -eq $dockerImageName }
        $imageExists = $null -ne $imageInfo
    }
    catch {
        # Ignore errors and assume image doesn't exist
    }

    # Build if requested or if image doesn't exist
    if ($BuildContainer -or -not $imageExists) {
        try {
            if (-not (Test-Path -Path $dockerfilePath)) {
                Write-Error "Dockerfile not found at $dockerfilePath"
                return $false
            }

            # Use the working directory where the Dockerfile is located
            Push-Location $dockerBuildPath

            # Build the Docker image
            & docker build -t $dockerImageName -f $dockerfilePath .
            $buildSuccess = $LASTEXITCODE -eq 0

            # Return to original directory
            Pop-Location

            if (-not $buildSuccess) {
                Write-Error "Failed to build Docker image."
                return $false
            }

            Write-Host "✅ Docker container built successfully." -ForegroundColor Green
            return $true
        }
        catch {
            Write-Error "Error building Docker container: $_"
            return $false
        }
    }
    else {
        Write-Host "ℹ️ Using existing Docker image." -ForegroundColor Cyan
        return $true
    }
}

# Run tests locally using Node.js
function Invoke-LocalTest {
    Write-Host "🧪 Running markdown linting tests locally..." -ForegroundColor Cyan

    try {
        # Check if Node.js is installed
        $nodeVersion = & node --version
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Node.js is required for local testing but was not found."
            return $false
        }

        # Check if markdownlint-cli2 is installed
        $lintInstalled = $null -ne (& npm list -g markdownlint-cli2 2>&1)

        if (-not $lintInstalled) {
            Write-Host "📦 Installing markdownlint-cli2..." -ForegroundColor Yellow
            & npm install -g markdownlint-cli2
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to install markdownlint-cli2."
                return $false
            }
        }

        # Build command arguments
        $cmdArgs = @()

        if (Test-Path -Path $ConfigFile) {
            $cmdArgs += "--config"
            $cmdArgs += """$ConfigFile"""
        }

        # Add custom rules directory if specified
        if (Test-Path -Path $RulesDirectory) {
            # Create a temporary config that includes custom rules
            $tempConfigPath = Join-Path -Path $env:TEMP -ChildPath "markdownlint-temp.json"

            if (Test-Path -Path $ConfigFile) {
                $configContent = Get-Content -Path $ConfigFile -Raw

                # Remove trailing closing brace and whitespace
                $configContent = $configContent -replace "}[\\s\\n]*$", ""

                # Add custom rules directive
                $customRulesPath = (Resolve-Path $RulesDirectory).Path
                $configContent += ",`n  `"customRules`": [`"$($customRulesPath.Replace("\", "\\"))/*.js`"]`n}"

                # Write to temp file
                $configContent | Out-File -FilePath $tempConfigPath -Encoding utf8

                # Update config path for command
                $cmdArgs = @("--config", """$tempConfigPath""")
            }
        }

        # Add path to markdown files
        $cmdArgs += """$Path/**/*.md"""

        # Run markdownlint-cli2
        $cmd = "markdownlint-cli2 $($cmdArgs -join ' ')"

        if ($Detailed) {
            Write-Host "📋 Running command: $cmd" -ForegroundColor DarkCyan
        }

        $output = & markdownlint-cli2 $cmdArgs
        $testSuccess = $LASTEXITCODE -eq 0

        if ($testSuccess) {
            Write-Host "✅ All markdown files passed linting!" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Markdown linting failed:" -ForegroundColor Red
            Write-Host $output
        }

        # Clean up temp file if created
        if (Test-Path -Path $tempConfigPath) {
            Remove-Item -Path $tempConfigPath -Force
        }

        return $testSuccess
    }
    catch {
        Write-Error "Error running local tests: $_"
        return $false
    }
}

# Run tests in Docker container
function Invoke-DockerTest {
    Write-Host "🐳 Running markdown linting tests in Docker..." -ForegroundColor Cyan

    try {
        # Mount paths for Docker volumes
        $pathAbs = (Resolve-Path $Path).Path
        $rulesAbs = (Resolve-Path $RulesDirectory).Path
        $configAbs = (Resolve-Path $ConfigFile).Path

        # Convert Windows paths to Docker paths
        $dockerPath = $pathAbs.Replace("\", "/").Replace("C:", "/c")
        $dockerRules = $rulesAbs.Replace("\", "/").Replace("C:", "/c")
        $dockerConfig = $configAbs.Replace("\", "/").Replace("C:", "/c")

        # Build command arguments
        $cmdArgs = @(
            "run", "--rm",
            "-v", "${pathAbs}:${dockerPath}",
            "-v", "${rulesAbs}:${dockerRules}",
            "-v", "${configAbs}:${dockerConfig}"
        )

        # Add detailed flag if specified
        if ($Detailed) {
            $cmdArgs += $dockerImageName
            $cmdArgs += "--verbose"
        }
        else {
            $cmdArgs += $dockerImageName
        }

        # Add test directory, config file, and rules directory
        $cmdArgs += "--test-dir"
        $cmdArgs += $dockerPath
        $cmdArgs += "--config"
        $cmdArgs += $dockerConfig
        $cmdArgs += "--rules-dir"
        $cmdArgs += $dockerRules

        # Execute Docker container
        if ($Detailed) {
            Write-Host "📋 Running Docker command:" -ForegroundColor DarkCyan
            Write-Host "docker $($cmdArgs -join ' ')" -ForegroundColor DarkGray
        }

        & docker $cmdArgs
        $testSuccess = $LASTEXITCODE -eq 0

        if ($testSuccess) {
            Write-Host "✅ All markdown files passed linting in Docker!" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Markdown linting failed in Docker." -ForegroundColor Red
        }

        return $testSuccess
    }
    catch {
        Write-Error "Error running Docker tests: $_"
        return $false
    }
}

# Main execution block
try {
    # Display information about the test run
    Write-Host "🚀 Markdown Linting Rule Tester" -ForegroundColor Cyan
    Write-Host "────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "Target Path: $Path" -ForegroundColor White
    Write-Host "Rules Directory: $RulesDirectory" -ForegroundColor White
    Write-Host "Config File: $ConfigFile" -ForegroundColor White
    Write-Host "Mode: $(if ($Local) { "Local" } else { "Docker" })" -ForegroundColor White
    Write-Host "────────────────────────────────" -ForegroundColor DarkCyan

    # Check if files exist
    if (-not (Test-Path -Path $Path)) {
        Write-Error "Test path not found: $Path"
        exit 1
    }

    if (-not (Test-Path -Path $RulesDirectory)) {
        Write-Error "Rules directory not found: $RulesDirectory"
        exit 1
    }

    if (-not (Test-Path -Path $ConfigFile)) {
        Write-Error "Config file not found: $ConfigFile"
        exit 1
    }

    # Run tests based on mode
    if ($Local) {
        $success = Invoke-LocalTest
    }
    else {
        # Check if Docker is available
        if (-not (Test-DockerAvailable)) {
            Write-Warning "Docker is not available. Falling back to local execution."
            $success = Invoke-LocalTest
        }
        else {
            # Build Docker container if needed
            $built = Build-DockerContainer

            if (-not $built) {
                Write-Warning "Failed to build Docker container. Falling back to local execution."
                $success = Invoke-LocalTest
            }
            else {
                $success = Invoke-DockerTest
            }
        }
    }

    # Exit with appropriate code
    if ($success) {
        Write-Host "🎉 Markdown linting tests completed successfully!" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Error "Markdown linting tests failed."
        exit 1
    }
}
catch {
    Write-Error "Error running markdown linting tests: $_"
    exit 1
}
