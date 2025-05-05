# Git.psm1
# Git operations and repository management functions for AutoGen

#Requires -Version 7.0

using module .\Common.psm1

# Module-level variables
$script:DefaultExcludePatterns = @(
    "*.env",
    ".env.*",
    "*.token",
    "*.key",
    "*.pem",
    "*_rsa",
    "*.ppk"
)

<#
.SYNOPSIS
    Configures Git with secure defaults for AutoGen development.
.DESCRIPTION
    Sets up Git configuration with secure settings, including user details and global gitignore.
.PARAMETER UserName
    The Git user name.
.PARAMETER Email
    The Git user email.
.PARAMETER EnableSignatures
    If true, enables commit signing.
.EXAMPLE
    Initialize-GitConfig -UserName $env:FORK_AUTOGEN_OWNER
#>
function Initialize-GitConfig {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$UserName = $env:FORK_AUTOGEN_OWNER,

        [Parameter()]
        [string]$Email,

        [Parameter()]
        [switch]$EnableSignatures
    )

    Write-SectionHeader "Git Configuration"

    # Configure Git to use the credential manager
    git config --global credential.helper manager-core
    Write-StatusMessage "Configured credential manager" "Success" 1

    # Set user name if provided
    if ($UserName) {
        git config --global user.name $UserName
        Write-StatusMessage "Set user name to: $UserName" "Success" 1
    }

    # Set email if provided, or get from GitHub if not
    if (-not $Email) {
        try {
            if ($env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN) {
                $headers = @{
                    Authorization = "token $env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN"
                    Accept = "application/vnd.github.v3+json"
                }

                $response = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get
                $Email = $response.email

                if (-not $Email) {
                    $Email = "$UserName@users.noreply.github.com"
                }
            }
            else {
                $Email = "$UserName@users.noreply.github.com"
            }
        }
        catch {
            Write-StatusMessage "Unable to get email from GitHub API" "Warning" 1
            $Email = "$UserName@users.noreply.github.com"
        }
    }

    git config --global user.email $Email
    Write-StatusMessage "Set user email to: $Email" "Success" 1

    # Configure SSH where possible
    git config --global url."git@github.com:".insteadOf "https://github.com/"
    Write-StatusMessage "Configured SSH preference for GitHub" "Success" 1

    # Configure commit signing if requested
    if ($EnableSignatures) {
        git config --global commit.gpgsign true
        Write-StatusMessage "Enabled GPG signing for commits" "Success" 1
    }

    # Create a global .gitignore for sensitive files
    $globalGitignore = "$env:USERPROFILE\.gitignore_global"

    $globalIgnoreContent = @"
# Global gitignore for sensitive files
# Created by AutoGen script

# Environment and secrets files
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
"@

    Set-Content -Path $globalGitignore -Value $globalIgnoreContent
    git config --global core.excludesfile $globalGitignore
    Write-StatusMessage "Created global gitignore at: $globalGitignore" "Success" 1

    Write-StatusMessage "Git configuration complete" "Emphasis" 0
}

<#
.SYNOPSIS
    Creates a commit with safe checks for sensitive content.
.DESCRIPTION
    Performs checks before committing to ensure no sensitive data is included.
.PARAMETER Files
    The files to commit.
.PARAMETER Message
    The commit message.
.PARAMETER SkipChecks
    Skip the sensitive content checks.
.EXAMPLE
    New-SafeCommit -Files @(".vscode/settings.json") -Message "Update settings"
#>
function New-SafeCommit {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Files,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter()]
        [switch]$SkipChecks
    )

    Write-SectionHeader "Creating Commit"

    $proceed = $true

    # Skip checks if requested
    if (-not $SkipChecks) {
        # Perform token scan on files
        foreach ($file in $Files) {
            if (Test-Path $file) {
                $exposedTokens = Find-ExposedTokens -FilePaths @($file)
                if ($exposedTokens) {
                    Write-StatusMessage "Found potential exposed tokens in $file" "Error" 1
                    $proceed = $false
                }
            }
            else {
                Write-StatusMessage "File not found: $file" "Warning" 1
            }
        }
    }

    # Proceed with commit if safe
    if ($proceed) {
        foreach ($file in $Files) {
            if (Test-Path $file) {
                git add $file
                Write-StatusMessage "Added file to commit: $file" "Success" 1
            }
        }

        git commit -m $Message
        Write-StatusMessage "Created commit: $Message" "Success" 0
        return $true
    }
    else {
        Write-StatusMessage "Commit canceled due to security concerns" "Error" 0
        return $false
    }
}

<#
.SYNOPSIS
    Removes sensitive data from Git history.
.DESCRIPTION
    Uses BFG Repo-Cleaner or git-filter-repo to purge sensitive information from history.
.PARAMETER TokenPatterns
    Regular expressions for tokens to remove.
.PARAMETER FilesToRemove
    Files to completely remove from history.
.PARAMETER UseFilterRepo
    Use git-filter-repo instead of BFG (advanced).
.EXAMPLE
    Remove-SensitiveDataFromHistory -FilesToRemove @(".env.local")
#>
function Remove-SensitiveDataFromHistory {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string[]]$TokenPatterns,

        [Parameter()]
        [string[]]$FilesToRemove,

        [Parameter()]
        [switch]$UseFilterRepo
    )

    Write-SectionHeader "Cleaning Repository History"

    # Check if there are any changes to staged
    $status = git status --porcelain
    if ($status) {
        Write-StatusMessage "Uncommitted changes detected. Please commit or stash them before cleaning history." "Error" 0
        return $false
    }

    # Create backup branch
    $date = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupBranch = "backup_before_cleanup_$date"
    git branch $backupBranch
    Write-StatusMessage "Created backup branch: $backupBranch" "Success" 1

    $success = $false

    if ($UseFilterRepo) {
        # Check if git-filter-repo is installed
        $gitFilterRepo = Get-Command git-filter-repo -ErrorAction SilentlyContinue
        if (-not $gitFilterRepo) {
            Write-StatusMessage "git-filter-repo not found. Please install it first." "Error" 1
            Write-StatusMessage "Run: pip install git-filter-repo" "Info" 1
            return $false
        }

        # Remove files
        if ($FilesToRemove) {
            $paths = $FilesToRemove -join " "
            Write-StatusMessage "Removing files from history: $paths" "Info" 1
            git filter-repo --path $paths --invert-paths
            $success = $true
        }

        # Remove tokens (requires more complex setup)
        if ($TokenPatterns) {
            Write-StatusMessage "Removing tokens with git-filter-repo requires custom scripting..." "Warning" 1
            $success = $false
        }
    }
    else {
        # Check if BFG is available
        $bfg = Get-Command bfg -ErrorAction SilentlyContinue
        if (-not $bfg) {
            Write-StatusMessage "BFG Repo-Cleaner not found. Please install it first." "Error" 1
            Write-StatusMessage "Download from: https://rtyley.github.io/bfg-repo-cleaner/" "Info" 1
            return $false
        }

        # Remove files
        if ($FilesToRemove) {
            $fileList = $FilesToRemove -join "',''"
            Write-StatusMessage "Removing files from history: $fileList" "Info" 1
            bfg --delete-files "$fileList"
            $success = $true
        }

        # Remove tokens
        if ($TokenPatterns) {
            foreach ($pattern in $TokenPatterns) {
                Write-StatusMessage "Removing tokens matching: $pattern" "Info" 1
                bfg --replace-text "$pattern"
            }
            $success = $true
        }
    }

    if ($success) {
        # Clean up after history modification
        git reflog expire --expire=now --all
        git gc --prune=now --aggressive
        Write-StatusMessage "Repository history cleaned successfully" "Success" 0
        return $true
    }
    else {
        Write-StatusMessage "History cleaning operation failed or no operations were performed" "Warning" 0
        return $false
    }
}

Export-ModuleMember -Function Initialize-GitConfig, New-SafeCommit, Remove-SensitiveDataFromHistory
