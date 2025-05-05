# This script is now a legacy wrapper that redirects to either auto-fix-git-auth.ps1 or setup-environment.ps1

Write-Host "Note: quick-fix-github-auth.ps1 is now deprecated." -ForegroundColor Yellow
Write-Host "We recommend using one of the following scripts instead:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. For automatic fix with no prompts:" -ForegroundColor Green
Write-Host "   .\auto-fix-git-auth.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. For interactive setup with prompts:" -ForegroundColor Green
Write-Host "   .\setup-environment.ps1" -ForegroundColor Cyan
Write-Host ""

$scriptChoice = Read-Host "Which script would you like to run? (1=auto, 2=interactive, or press Enter for auto)"

if ([string]::IsNullOrWhiteSpace($scriptChoice) -or $scriptChoice -eq "1") {
    Write-Host "Running automatic fix script..." -ForegroundColor Green
    & "$PSScriptRoot\auto-fix-git-auth.ps1"
} elseif ($scriptChoice -eq "2") {
    Write-Host "Running interactive setup script..." -ForegroundColor Green
    & "$PSScriptRoot\setup-environment.ps1"
} else {
    Write-Host "Invalid choice. Exiting." -ForegroundColor Red
    exit 1
}

function Configure-GitCredentials {
    param (
        [string]$Token,
        [string]$Owner
    )

    Write-Host "Configuring Git to use HTTPS with personal access token..." -ForegroundColor Cyan

    # Configure Git to use HTTPS with personal access token
    git config --global url."https://$Token@github.com/$Owner".insteadOf "git@github.com:$Owner"
    git config --global url."https://$Token@github.com/$Owner".insteadOf "https://github.com/$Owner"

    Write-Host "✓ Git configured to use HTTPS with personal access token for $Owner repositories" -ForegroundColor Green
}

# Clear the screen
Clear-Host

Write-Host "GitHub Authentication Setup Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "This script will help you fix Git authentication issues with GitHub."
Write-Host "It will configure Git to use HTTPS with a personal access token."
Write-Host ""

# Check if environment variables are already set
$envToken = [Environment]::GetEnvironmentVariable("FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN", "Process")
$envOwner = [Environment]::GetEnvironmentVariable("FORK_AUTOGEN_OWNER", "Process")
$envRepo = [Environment]::GetEnvironmentVariable("REPO_PATH", "Process")
if ([string]::IsNullOrWhiteSpace($envRepo)) {
    $envRepo = "autogen"
}

$useEnvVars = $false
if ((-not [string]::IsNullOrWhiteSpace($envToken)) -and (-not [string]::IsNullOrWhiteSpace($envOwner))) {
    Write-Host "Found environment variables for GitHub authentication." -ForegroundColor Green
    Write-Host "Owner: $envOwner" -ForegroundColor Cyan
    $confirmUseEnv = Read-Host "Do you want to use these environment variables? (Y/n)"
    if ([string]::IsNullOrWhiteSpace($confirmUseEnv) -or $confirmUseEnv.ToLower() -eq "y") {
        $useEnvVars = $true
        $token = $envToken
        $owner = $envOwner
        $repo = $envRepo
    }
}

if (-not $useEnvVars) {
    # Get GitHub username
    if (-not [string]::IsNullOrWhiteSpace($envOwner)) {
        $owner = Read-Host "Enter your GitHub username (default: $envOwner)"
        if ([string]::IsNullOrWhiteSpace($owner)) {
            $owner = $envOwner
        }
    } else {
        $owner = Read-Host "Enter your GitHub username (e.g., DeanLuus22021994)"
        while ([string]::IsNullOrWhiteSpace($owner)) {
            Write-Host "GitHub username is required." -ForegroundColor Red
            $owner = Read-Host "Enter your GitHub username"
        }
    }

    # Get GitHub personal access token
    $secureToken = Read-Host "Enter your GitHub Personal Access Token (PAT)" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    while ([string]::IsNullOrWhiteSpace($token)) {
        Write-Host "GitHub Personal Access Token is required." -ForegroundColor Red
        $secureToken = Read-Host "Enter your GitHub Personal Access Token (PAT)" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }

    # Get repository name
    if (-not [string]::IsNullOrWhiteSpace($envRepo)) {
        $repo = Read-Host "Enter the repository name (default: $envRepo)"
        if ([string]::IsNullOrWhiteSpace($repo)) {
            $repo = $envRepo
        }
    } else {
        $repo = Read-Host "Enter the repository name (default: autogen)"
        if ([string]::IsNullOrWhiteSpace($repo)) {
            $repo = "autogen"
        }
    }
}

# Configure Git credentials
Configure-GitCredentials -Token $token -Owner $owner

# Test the connection
$connectionSuccessful = Test-GitHubConnection -Token $token -Owner $owner -Repo $repo

if ($connectionSuccessful) {
    # Ask if user wants to permanently store these values as environment variables
    $storeEnvVars = Read-Host "Do you want to store these values as environment variables for future use? (Y/n)"
    if ([string]::IsNullOrWhiteSpace($storeEnvVars) -or $storeEnvVars.ToLower() -eq "y") {
        [Environment]::SetEnvironmentVariable("FORK_AUTOGEN_OWNER", $owner, "User")
        [Environment]::SetEnvironmentVariable("FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN", $token, "User")
        [Environment]::SetEnvironmentVariable("REPO_PATH", $repo, "User")

        # Also set for current session
        [Environment]::SetEnvironmentVariable("FORK_AUTOGEN_OWNER", $owner, "Process")
        [Environment]::SetEnvironmentVariable("FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN", $token, "Process")
        [Environment]::SetEnvironmentVariable("REPO_PATH", $repo, "Process")

        Write-Host "✓ Environment variables have been saved successfully." -ForegroundColor Green
    }

    # Offer to test the specific command that failed previously
    $testSpecificCommand = Read-Host "Do you want to test the 'git pull --tags origin DeanDev' command now? (Y/n)"
    if ([string]::IsNullOrWhiteSpace($testSpecificCommand) -or $testSpecificCommand.ToLower() -eq "y") {
        Write-Host "Testing 'git pull --tags origin DeanDev'..." -ForegroundColor Cyan
        git pull --tags origin DeanDev
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Command executed successfully!" -ForegroundColor Green
        } else {
            Write-Host "✗ Command failed. You may need additional configuration." -ForegroundColor Red
        }
    }
} else {
    Write-Host "Authentication setup failed. Please check the following:" -ForegroundColor Red
    Write-Host "1. Ensure your GitHub token has the correct permissions (repo, read:packages)" -ForegroundColor Yellow
    Write-Host "2. Verify that your token has not expired" -ForegroundColor Yellow
    Write-Host "3. Confirm that the repository exists and you have access to it" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Current Git configuration:" -ForegroundColor Cyan
git config --global --list | Select-String "url\."
