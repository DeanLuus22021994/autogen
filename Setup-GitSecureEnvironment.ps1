# Setup-GitSecureEnvironment.ps1
# This script sets up a secure Git environment and helps clean sensitive data from the repository

param (
    [switch]$SetupGit,
    [switch]$CleanHistory,
    [switch]$ConfigureGitHubCLI
)

# Colors for console output
$colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
}

function Write-ColorMessage {
    param (
        [string]$Message,
        [string]$Color = "White"
    )

    Write-Host $Message -ForegroundColor $Color
}

function Setup-Git {
    Write-ColorMessage "Setting up Git configuration..." $colors.Info

    # Configure Git to use the credential manager
    git config --global credential.helper manager-core

    # Set up Git to use environment variables instead of hardcoded values
    git config --global user.name $env:FORK_AUTOGEN_OWNER

    # Get email from GitHub API
    try {
        $token = $env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN
        $headers = @{
            Authorization = "token $token"
            Accept = "application/vnd.github.v3+json"
        }

        $response = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get
        $email = $response.email

        if (-not $email) {
            $email = "$env:FORK_AUTOGEN_OWNER@users.noreply.github.com"
        }

        git config --global user.email $email
        Write-ColorMessage "  ✅ Git user email set to: $email" $colors.Success
    } catch {
        Write-ColorMessage "  ⚠️ Could not get email from GitHub API. Using default." $colors.Warning
        git config --global user.email "$env:FORK_AUTOGEN_OWNER@users.noreply.github.com"
    }

    # Configure Git to use SSH where possible
    git config --global url."git@github.com:".insteadOf "https://github.com/"

    # Set Git to warn about sensitive data
    git config --global hooks.allowedcommands "git-secrets --scan"

    # Create a global .gitignore for sensitive files
    $globalGitignore = "$env:USERPROFILE\.gitignore_global"
    @"
# Environment files
.env.local
.env.*.local
*.token
*.key
*.pem
*_rsa
*.ppk

# VS Code files
.vscode/temp/
.vscode/localhistory/

# Log files
*.log
logs/

# Temporary files
*.tmp
*~
*.bak
*.swp
"@ | Set-Content -Path $globalGitignore

    git config --global core.excludesfile $globalGitignore

    Write-ColorMessage "Git configuration complete ✅" $colors.Success
}

function Install-GitSecrets {
    Write-ColorMessage "Installing git-secrets to prevent committing sensitive data..." $colors.Info

    # Check if git-secrets is already installed
    $gitSecretsInstalled = $null -ne (Get-Command "git-secrets" -ErrorAction SilentlyContinue)

    if (-not $gitSecretsInstalled) {
        # For Windows, we'll use a PowerShell-based approach
        $gitSecretsDir = "$env:USERPROFILE\git-secrets"

        if (-not (Test-Path $gitSecretsDir)) {
            git clone https://github.com/awslabs/git-secrets.git $gitSecretsDir
        }

        # Add to PATH if needed
        $path = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($path -notlike "*$gitSecretsDir*") {
            [Environment]::SetEnvironmentVariable("PATH", "$path;$gitSecretsDir", "User")
            $env:PATH = "$env:PATH;$gitSecretsDir"
        }
    }

    # Configure git-secrets for the current repository
    Push-Location
    try {
        Set-Location (Get-Location)

        # Initialize git-secrets
        git secrets --install

        # Add patterns for common secrets
        git secrets --add 'GITHUB_PERSONAL_ACCESS_TOKEN.*=.*[''"][a-zA-Z0-9_]*[''"]'
        git secrets --add 'ghp_[a-zA-Z0-9_]{36}'
        git secrets --add 'github_pat_[a-zA-Z0-9_]{82}'
        git secrets --add 'DOCKER.*TOKEN.*=.*[''"][a-zA-Z0-9_]*[''"]'
        git secrets --add 'HUGGINGFACE.*TOKEN.*=.*[''"][a-zA-Z0-9_]*[''"]'

        # Add allowed patterns for environment variable usage
        git secrets --add --allowed '\${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}'
        git secrets --add --allowed '\${env:FORK_USER_DOCKER_ACCESS_TOKEN}'
        git secrets --add --allowed '\${env:FORK_HUGGINGFACE_ACCESS_TOKEN}'

        Write-ColorMessage "  ✅ Git secrets configured for this repository" $colors.Success
    } finally {
        Pop-Location
    }
}

function Clean-GitHistory {
    Write-ColorMessage "Cleaning Git history of sensitive information..." $colors.Warning

    # Download BFG Repo Cleaner if not already present
    $bfgPath = Join-Path $pwd "bfg.jar"
    if (-not (Test-Path $bfgPath)) {
        $bfgUrl = "https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar"
        Write-ColorMessage "Downloading BFG Repo Cleaner..." $colors.Info
        Invoke-WebRequest -Uri $bfgUrl -OutFile $bfgPath
    }

    # Create replacements file
    $replacementsPath = Join-Path $pwd "replacements.txt"
    @"
# Patterns for GitHub tokens
ghp_[a-zA-Z0-9_]{36}==>***REMOVED***
github_pat_[a-zA-Z0-9_]{82}==>***REMOVED***

# Patterns for other tokens
GITHUB_PERSONAL_ACCESS_TOKEN.*=.*"[^"]*"==>GITHUB_PERSONAL_ACCESS_TOKEN="\${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"
"@ | Set-Content -Path $replacementsPath

    # Backup the repository
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupDir = Join-Path $pwd "git-backup-$timestamp"
    Write-ColorMessage "Creating backup at $backupDir..." $colors.Info
    Copy-Item -Path (Join-Path $pwd ".git") -Destination $backupDir -Recurse

    # Run BFG
    Write-ColorMessage "Running BFG Repo Cleaner (this may take some time)..." $colors.Warning
    java -jar $bfgPath --replace-text $replacementsPath

    # Clean up
    git reflog expire --expire=now --all
    git gc --prune=now --aggressive

    # Remove temporary files
    if (Test-Path $replacementsPath) {
        Remove-Item $replacementsPath -Force
    }

    Write-ColorMessage "Git history cleaned. You need to force push these changes:" $colors.Success
    Write-ColorMessage "git push --force" $colors.Warning
    Write-ColorMessage "Backup of original repository is at: $backupDir" $colors.Info
}

function Configure-GitHubCLI {
    Write-ColorMessage "Setting up GitHub CLI..." $colors.Info

    # Check if GitHub CLI is installed
    $ghInstalled = $null -ne (Get-Command "gh" -ErrorAction SilentlyContinue)

    if (-not $ghInstalled) {
        Write-ColorMessage "GitHub CLI (gh) is not installed. Please install it first:" $colors.Error
        Write-ColorMessage "https://github.com/cli/cli#installation" $colors.Info
        return
    }

    # Log in to GitHub using the PAT
    $token = $env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN

    if (-not $token) {
        Write-ColorMessage "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN is not set. Please set it first." $colors.Error
        return
    }

    # Log in with the token
    $token | gh auth login --with-token

    # Verify login
    $loginStatus = gh auth status

    if ($loginStatus -like "*Logged in to github.com*") {
        Write-ColorMessage "  ✅ Successfully logged in to GitHub CLI" $colors.Success

        # Configure secret scanning for the repository
        Write-ColorMessage "Enabling push protection in the repository..." $colors.Info

        gh api repos/$env:FORK_AUTOGEN_OWNER/autogen/code-scanning/default-setup -X PUT -F state=configured
        gh secret-scanning enable $env:FORK_AUTOGEN_OWNER/autogen
        gh secret-scanning push-protection enable $env:FORK_AUTOGEN_OWNER/autogen

        Write-ColorMessage "  ✅ Secret scanning and push protection enabled" $colors.Success
    } else {
        Write-ColorMessage "  ❌ Failed to log in to GitHub CLI" $colors.Error
    }
}

# Main script execution
if ($SetupGit) {
    Setup-Git
    Install-GitSecrets
} elseif ($CleanHistory) {
    Clean-GitHistory
} elseif ($ConfigureGitHubCLI) {
    Configure-GitHubCLI
} else {
    Write-ColorMessage "Please specify an operation: -SetupGit, -CleanHistory, or -ConfigureGitHubCLI" $colors.Warning
}
