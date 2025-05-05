# Validate-Environment.ps1
# Validates that the environment is properly configured for AutoGen development

#Requires -Version 7.0

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
$modulesPath = $rootPath

# Import all modules
Import-Module "$modulesPath\Common.psm1" -Force
Import-Module "$modulesPath\Environment.psm1" -Force
Import-Module "$modulesPath\Security.psm1" -Force
Import-Module "$modulesPath\Git.psm1" -Force
Import-Module "$modulesPath\VSCode.psm1" -Force

function Start-EnvironmentValidation {
    Write-Host ""
    Write-SectionHeader "AutoGen Environment Validation"
    Write-StatusMessage "Starting environment validation..." "Info" 0

    # List of required environment variables
    $requiredVariables = @(
        "FORK_AUTOGEN_OWNER",
        "FORK_AUTOGEN_REPO",
        "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN"
    )

    # Optional but recommended variables
    $optionalVariables = @(
        "OPENAI_API_KEY",
        "FORK_HUGGINGFACE_ACCESS_TOKEN"
    )

    # Check required environment variables
    $requiredStatus = Test-EnvironmentVariables -RequiredVariables $requiredVariables

    if (-not $requiredStatus) {
        Write-StatusMessage "Missing required environment variables. Please set them and try again." "Error" 0
    }
    else {
        Write-StatusMessage "All required environment variables are set." "Success" 0
    }

    # Check optional environment variables
    $optionalStatus = Test-EnvironmentVariables -RequiredVariables $optionalVariables -Optional

    # Check for exposed tokens in VS Code configuration
    $configSecure = Test-VSCodeConfigSecurity

    if (-not $configSecure) {
        Write-StatusMessage "Please run 'Fix Security Issues' task to remediate security concerns" "Warning" 0
    }

    # Check Git configuration
    $repoUrl = git config --get remote.origin.url
    if ($repoUrl -match "github.com/([^/]+)/([^/\.]+)") {
        $owner = $Matches[1]
        $repo = $Matches[2]

        if ($owner -eq $env:FORK_AUTOGEN_OWNER -and $repo -eq $env:FORK_AUTOGEN_REPO) {
            Write-StatusMessage "Git repository configured correctly" "Success" 0
        }
        else {
            Write-StatusMessage "Git repository configuration doesn't match environment variables" "Warning" 0
            Write-StatusMessage "Current remote: $owner/$repo" "Info" 1
            Write-StatusMessage "Environment variables: $env:FORK_AUTOGEN_OWNER/$env:FORK_AUTOGEN_REPO" "Info" 1
            Write-StatusMessage "Run 'Verify GitHub Setup' task to fix this" "Info" 1
        }
    }
    else {
        Write-StatusMessage "Unable to determine Git repository configuration" "Warning" 0
    }

    # Check Python environment
    $pythonVersion = python --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-StatusMessage "Python detected: $pythonVersion" "Success" 0

        # Check if virtual environment is active
        if ($env:VIRTUAL_ENV) {
            Write-StatusMessage "Virtual environment is active: $env:VIRTUAL_ENV" "Success" 1
        }
        else {
            Write-StatusMessage "No virtual environment detected" "Warning" 1
            Write-StatusMessage "Consider creating one with: python -m venv .venv" "Info" 1
        }
    }
    else {
        Write-StatusMessage "Python not found in PATH" "Error" 0
    }

    # Output overall status
    Write-Host ""
    if ($requiredStatus -and $configSecure) {
        Write-StatusMessage "Environment validation completed successfully" "Success" 0
    }
    else {
        Write-StatusMessage "Environment validation completed with issues" "Warning" 0
        Write-StatusMessage "Please address the issues above before continuing" "Info" 0
    }
    Write-Host ""
}

# Run the validation
Start-EnvironmentValidation
