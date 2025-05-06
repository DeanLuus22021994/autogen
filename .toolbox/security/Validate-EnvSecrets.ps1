# Validate-EnvSecrets.ps1
# A script to validate and manage environment variables and secrets for the AutoGen repository

param (
    [switch]$Setup,
    [switch]$Validate,
    [switch]$Fix
)

# Colors for console output
$colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
}

# Required environment variables
$requiredEnvVars = @(
    "REPO_PATH",
    "FORK_AUTOGEN_OWNER",
    "FORK_AUTOGEN_SSH_REPO_URL",
    "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN",
    "FORK_AUTOGEN_USER_DOCKER_USERNAME",
    "FORK_USER_DOCKER_ACCESS_TOKEN",
    "FORK_HUGGINGFACE_ACCESS_TOKEN"
)

function Write-ColorMessage {
    param (
        [string]$Message,
        [string]$Color = "White"
    )

    Write-Host $Message -ForegroundColor $Color
}

function Test-EnvironmentVariables {
    Write-ColorMessage "Validating environment variables..." $colors.Info
    $missingVars = @()

    foreach ($var in $requiredEnvVars) {
        if (-not (Get-Item "env:$var" -ErrorAction SilentlyContinue)) {
            Write-ColorMessage "  ❌ Missing: $var" $colors.Error
            $missingVars += $var
        } else {
            Write-ColorMessage "  ✅ Found: $var" $colors.Success
        }
    }

    return $missingVars
}

function Set-EnvironmentVariablesPermanently {
    param (
        [array]$Variables
    )

    foreach ($var in $Variables) {
        $value = Read-Host "Enter value for $var (leave empty to skip)"
        if ($value) {
            [System.Environment]::SetEnvironmentVariable($var, $value, "User")
            Write-ColorMessage "  ✅ Set $var at user level" $colors.Success
        }
    }

    Write-ColorMessage "Environment variables have been set. Please restart your terminal or IDE for changes to take effect." $colors.Warning
}

function Update-ConfigFiles {
    Write-ColorMessage "Updating configuration files to use environment variables..." $colors.Info

    # Update .env file
    $envPath = Join-Path $pwd ".env"
    $envContent = @"
# AutoGen environment variables
# WARNING: Do not commit tokens to version control!

# Repository configuration
REPO_PATH=$env:REPO_PATH

# GitHub configuration
FORK_AUTOGEN_OWNER=$env:FORK_AUTOGEN_OWNER
FORK_AUTOGEN_SSH_REPO_URL=$env:FORK_AUTOGEN_SSH_REPO_URL
# Personal access token should be set in your environment variables
# FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN

# Docker configuration
FORK_AUTOGEN_USER_DOCKER_USERNAME=$env:FORK_AUTOGEN_USER_DOCKER_USERNAME
# Docker access token should be set in your environment variables
# FORK_USER_DOCKER_ACCESS_TOKEN

# Hugging Face configuration
# Access token should be set in your environment variables
# FORK_HUGGINGFACE_ACCESS_TOKEN
"@
    Set-Content -Path $envPath -Value $envContent
    Write-ColorMessage "  ✅ Updated .env file" $colors.Success

    # Create .gitignore for tokens if it doesn't exist
    $gitignorePath = Join-Path $pwd ".gitignore"
    $gitignoreContent = Get-Content $gitignorePath

    $tokenPatterns = @(
        "*.env.local",
        "*.token",
        "*.secret"
    )

    $updated = $false
    foreach ($pattern in $tokenPatterns) {
        if ($gitignoreContent -notcontains $pattern) {
            Add-Content -Path $gitignorePath -Value $pattern
            $updated = $true
        }
    }

    if ($updated) {
        Write-ColorMessage "  ✅ Updated .gitignore with token patterns" $colors.Success
    } else {
        Write-ColorMessage "  ✅ .gitignore already contains token patterns" $colors.Success
    }
}

function Test-GitHubSecrets {
    Write-ColorMessage "Validating GitHub repository secrets..." $colors.Info

    try {
        $token = $env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN
        $owner = $env:FORK_AUTOGEN_OWNER
        $repo = "autogen"

        $headers = @{
            Authorization = "token $token"
            Accept = "application/vnd.github.v3+json"
        }

        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/actions/secrets" -Headers $headers -Method Get

        $requiredSecrets = @(
            "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN",
            "FORK_USER_DOCKER_ACCESS_TOKEN",
            "FORK_HUGGINGFACE_ACCESS_TOKEN"
        )

        $missingSecrets = @()
        foreach ($secret in $requiredSecrets) {
            if ($response.secrets.name -contains $secret) {
                Write-ColorMessage "  ✅ Found GitHub secret: $secret" $colors.Success
            } else {
                Write-ColorMessage "  ❌ Missing GitHub secret: $secret" $colors.Error
                $missingSecrets += $secret
            }
        }

        return $missingSecrets
    } catch {
        Write-ColorMessage "Error accessing GitHub API: $_" $colors.Error
        return $requiredSecrets
    }
}

function Add-GitHubSecrets {
    param (
        [array]$Secrets
    )

    Write-ColorMessage "Adding missing GitHub secrets..." $colors.Info

    try {
        $token = $env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN
        $owner = $env:FORK_AUTOGEN_OWNER
        $repo = "autogen"

        $headers = @{
            Authorization = "token $token"
            Accept = "application/vnd.github.v3+json"
        }

        # First, get the public key for the repository
        $keyResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/actions/secrets/public-key" -Headers $headers -Method Get
        $publicKey = $keyResponse.key
        $keyId = $keyResponse.key_id

        # For each missing secret, prompt for value and set it
        foreach ($secret in $Secrets) {
            $value = Read-Host "Enter value for GitHub secret $secret (leave empty to skip)"
            if ($value) {
                # In a production script, you would encrypt the value with the public key
                # For demonstration, we're showing the API call without encryption
                Write-ColorMessage "  🔄 Setting GitHub secret: $secret" $colors.Warning

                # In a real implementation, you would encrypt the value with the public key here
                # This is a placeholder for the actual encryption code

                $body = @{
                    encrypted_value = $value  # This should be encrypted in production
                    key_id = $keyId
                } | ConvertTo-Json

                $secretUrl = "https://api.github.com/repos/$owner/$repo/actions/secrets/$secret"
                Invoke-RestMethod -Uri $secretUrl -Headers $headers -Method Put -Body $body -ContentType "application/json"

                Write-ColorMessage "  ✅ Set GitHub secret: $secret" $colors.Success
            }
        }
    } catch {
        Write-ColorMessage "Error setting GitHub secrets: $_" $colors.Error
    }
}

function Remove-GitHistory {
    Write-ColorMessage "Checking git history for sensitive information..." $colors.Info

    # Check if BFG Repo Cleaner is installed
    $bfgExists = $null -ne (Get-Command "java" -ErrorAction SilentlyContinue)

    if (-not $bfgExists) {
        Write-ColorMessage "Java is required for BFG Repo Cleaner. Please install Java and try again." $colors.Error
        return
    }    # Download BFG if not already present
    $bfgPath = Join-Path $pwd "bfg.jar"
    if (-not (Test-Path $bfgPath)) {
        $bfgUrl = "https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar"
        Write-ColorMessage "Downloading BFG Repo Cleaner..." $colors.Info
        Invoke-WebRequest -Uri $bfgUrl -OutFile $bfgPath
    }

    # Create a file with patterns to replace
    $replacementsPath = Join-Path $pwd "replacements.txt"
    @"
GITHUB_PERSONAL_ACCESS_TOKEN==>***REMOVED***
github_pat_=>***REMOVED***
ghp_=>***REMOVED***
"@ | Set-Content -Path $replacementsPath

    # Run BFG to clean history
    Write-ColorMessage "Cleaning git history with BFG Repo Cleaner..." $colors.Warning
    Write-ColorMessage "This may take some time..." $colors.Info

    Push-Location
    try {
        Set-Location $pwd

        # First, create a backup of the current state
        $backupDir = Join-Path $pwd "git-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Copy-Item -Path (Join-Path $pwd ".git") -Destination $backupDir -Recurse

        # Run BFG
        java -jar $bfgPath --replace-text $replacementsPath

        # Clean up the git repository
        git reflog expire --expire=now --all
        git gc --prune=now --aggressive

        Write-ColorMessage "Git history cleaned. You should force push these changes:" $colors.Success
        Write-ColorMessage "git push --force" $colors.Warning
    } finally {
        Pop-Location

        # Clean up temporary files
        if (Test-Path $replacementsPath) {
            Remove-Item $replacementsPath -Force
        }
    }
}

function Test-DevelopmentConfiguration {
    <#
    .SYNOPSIS
        Tests the development environment configuration.
    .DESCRIPTION
        Checks for required configuration files and tools for development.
    .EXAMPLE
        Test-DevelopmentConfiguration
    #>
    [CmdletBinding()]
    param()

    Write-ColorMessage "Validating development environment configuration..." $colors.Info
    $issues = @()

    # Check for VS Code configuration
    if (Test-Path ".vscode") {
        Write-ColorMessage "  ✅ VS Code configuration folder exists" $colors.Success

        # Check for essential VS Code files
        $vsCodeFiles = @(
            ".vscode/settings.json",
            ".vscode/tasks.json",
            ".vscode/launch.json"
        )

        foreach ($file in $vsCodeFiles) {
            if (Test-Path $file) {
                Write-ColorMessage "    ✅ $file exists" $colors.Success
            } else {
                Write-ColorMessage "    ❌ $file is missing" $colors.Warning
                $issues += "Missing VS Code configuration file: $file"
            }
        }
    } else {
        Write-ColorMessage "  ❌ VS Code configuration folder is missing" $colors.Warning
        $issues += "Missing VS Code configuration folder"
    }

    # Check for spell check configuration
    $spellCheckFiles = @(
        ".config/cspell-dictionary.txt",
        ".devcontainer/spell-check.sh",
        ".devcontainer/manage-dictionary.sh"
    )

    foreach ($file in $spellCheckFiles) {
        if (Test-Path $file) {
            Write-ColorMessage "  ✅ $file exists" $colors.Success
        } else {
            Write-ColorMessage "  ❌ $file is missing" $colors.Warning
            $issues += "Missing spell check configuration file: $file"
        }
    }

    # Check for PowerShell modules
    if (Test-Path ".scripts/automation/github") {
        Write-ColorMessage "  ✅ PowerShell automation modules exist" $colors.Success
    } else {
        Write-ColorMessage "  ❌ PowerShell automation modules are missing" $colors.Warning
        $issues += "Missing PowerShell automation modules"
    }

    return $issues
}

# Main script execution
if ($Setup) {
    Write-ColorMessage "Setting up environment for AutoGen development..." $colors.Info
    $missingVars = Test-EnvironmentVariables

    if ($missingVars.Count -gt 0) {
        $setupVars = Read-Host "Do you want to set up missing environment variables? (Y/N)"
        if ($setupVars -eq "Y") {
            Set-EnvironmentVariablesPermanently -Variables $missingVars
        }
    }    Update-ConfigFiles

    # Check development configuration
    $devConfigIssues = Test-DevelopmentConfiguration
    if ($devConfigIssues.Count -gt 0) {
        $fixDevConfig = Read-Host "Do you want to fix development configuration issues? (Y/N)"
        if ($fixDevConfig -eq "Y") {
            Write-ColorMessage "Setting up development configuration..." $colors.Info

            # Import Sync-ConfigurationFiles.ps1 if it exists
            $syncConfigPath = ".scripts/automation/config/Sync-ConfigurationFiles.ps1"
            if (Test-Path $syncConfigPath) {
                & $syncConfigPath -SyncAll -Force
                Write-ColorMessage "Development configuration updated!" $colors.Success
            } else {
                Write-ColorMessage "Could not find Sync-ConfigurationFiles.ps1. Please run it manually." $colors.Error
            }
        }
    }

    $checkSecrets = Read-Host "Do you want to check GitHub repository secrets? (Y/N)"
    if ($checkSecrets -eq "Y") {
        $missingSecrets = Test-GitHubSecrets

        if ($missingSecrets.Count -gt 0) {
            $setupSecrets = Read-Host "Do you want to set up missing GitHub secrets? (Y/N)"
            if ($setupSecrets -eq "Y") {
                Add-GitHubSecrets -Secrets $missingSecrets
            }
        }
    }
} elseif ($Validate) {
    $missingVars = Test-EnvironmentVariables

    if ($missingVars.Count -eq 0) {
        Write-ColorMessage "All required environment variables are set." $colors.Success
    } else {
        Write-ColorMessage "Missing environment variables detected. Run with -Setup to configure them." $colors.Error
    }

    $missingSecrets = Test-GitHubSecrets

    if ($missingSecrets.Count -eq 0) {
        Write-ColorMessage "All required GitHub secrets are set." $colors.Success
    } else {
        Write-ColorMessage "Missing GitHub secrets detected. Run with -Setup to configure them." $colors.Error
    }

    $devIssues = Test-DevelopmentConfiguration
    if ($devIssues.Count -eq 0) {
        Write-ColorMessage "Development environment configuration is complete." $colors.Success
    } else {
        Write-ColorMessage "Issues detected in development environment configuration:" $colors.Warning
        foreach ($issue in $devIssues) {
            Write-ColorMessage "  - $issue" $colors.Warning
        }
        Write-ColorMessage "Review and fix the above issues, then re-run the validation." $colors.Warning
    }
} elseif ($Fix) {
    Clean-GitHistory
} else {
    Write-ColorMessage "Please specify an operation: -Setup, -Validate, or -Fix" $colors.Warning
}
