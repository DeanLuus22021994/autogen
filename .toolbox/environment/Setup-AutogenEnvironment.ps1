# Setup-AutogenEnvironment.ps1
# Master script to set up and validate the AutoGen development environment
# This is a legacy script that now redirects to the new modular system

param (
    [switch]$Initialize,
    [switch]$Validate,
    [switch]$FixTokens,
    [switch]$All
)

# Colors for console output
$colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Header = "Magenta"
}

function Write-ColorMessage {
    param (
        [string]$Message,
        [string]$Color = "White"
    )

    Write-Host $Message -ForegroundColor $Color
}

function Initialize-Environment {
    Write-ColorMessage "`n========== INITIALIZING ENVIRONMENT ==========" $colors.Header

    # Call the new orchestration scripts
    Write-ColorMessage "Calling new GitHub setup script..." $colors.Info
    & ".\.scripts\automation\github\orchestration\Verify-GitHubSetup.ps1"

    Write-ColorMessage "Calling new VS Code setup script..." $colors.Info
    & ".\.scripts\automation\github\orchestration\Commit-VSCodeConfig.ps1"

    Write-ColorMessage "`nEnvironment initialization complete." $colors.Success
}

    # Step 1: Check if required environment variables are set
    Write-ColorMessage "`nValidating environment variables..." $colors.Info
    & "\$PSScriptRoot\..\..\\Validate-EnvSecrets.ps1" -Validate

    if ($LASTEXITCODE -ne 0) {
        $setupVars = Read-Host "Would you like to set up missing environment variables now? (Y/N)"
        if ($setupVars -eq "Y" -or $setupVars -eq "y") {
            & "\$PSScriptRoot\..\..\\Validate-EnvSecrets.ps1" -Setup
        }
    }

    # Step 2: Set up Git configurations
    Write-ColorMessage "`nConfiguring Git for secure development..." $colors.Info
    & "\$PSScriptRoot\..\..\\Setup-GitSecureEnvironment.ps1" -SetupGit

    # Step 3: Check and fix token issues
    Write-ColorMessage "`nChecking for token issues in the repository..." $colors.Info
    & "\$PSScriptRoot\..\..\\Resolve-PushBlockedByToken.ps1"

    Write-ColorMessage "`nEnvironment initialization complete!" $colors.Success
    Write-ColorMessage "You may need to restart your terminal or VS Code for all changes to take effect." $colors.Warning
}

function Validate-FullEnvironment {
    Write-ColorMessage "`n========== VALIDATING ENVIRONMENT ==========" $colors.Header

    # Validate environment variables
    Write-ColorMessage "`nValidating environment variables..." $colors.Info
    & "\$PSScriptRoot\..\..\\Validate-EnvSecrets.ps1" -Validate

    # Validate Git configuration
    Write-ColorMessage "`nValidating Git configuration..." $colors.Info
    $gitConfig = git config --list

    if ($gitConfig -match "credential.helper=manager-core") {
        Write-ColorMessage "  ✅ Git credential helper is configured correctly" $colors.Success
    } else {
        Write-ColorMessage "  ❌ Git credential helper is not configured correctly" $colors.Error
        Write-ColorMessage "     Run 'Setup-GitSecureEnvironment.ps1 -SetupGit' to fix" $colors.Info
    }

    # Check for token patterns in files
    Write-ColorMessage "`nChecking for token patterns in tracked files..." $colors.Info
    $tokenPatterns = @(
        "ghp_[a-zA-Z0-9]{36}",
        "github_pat_[a-zA-Z0-9_]{22}",
        "PERSONAL_ACCESS_TOKEN.*=.*[^$]"
    )

    $hasIssues = $false
    foreach ($pattern in $tokenPatterns) {
        $results = git grep -l -E $pattern -- ":(exclude).env" ":(exclude)*.md" 2>$null
        if ($results) {
            Write-ColorMessage "  ❌ Found potential token patterns in these files:" $colors.Error
            $results | ForEach-Object { Write-ColorMessage "     - $_" $colors.Warning }
            $hasIssues = $true
        }
    }

    if (-not $hasIssues) {
        Write-ColorMessage "  ✅ No token patterns found in tracked files" $colors.Success
    } else {
        Write-ColorMessage "     Run 'Setup-AutogenEnvironment.ps1 -FixTokens' to fix token issues" $colors.Info
    }

    Write-ColorMessage "`nEnvironment validation complete!" $colors.Success
}

function Fix-TokenIssues {
    Write-ColorMessage "`n========== FIXING TOKEN ISSUES ==========" $colors.Header
    & "\$PSScriptRoot\..\..\\Resolve-PushBlockedByToken.ps1" -Fix
}

# Main script execution
if ($Initialize -or $All) {
    Initialize-Environment
}

if ($Validate -or $All) {
    Validate-FullEnvironment
}

if ($FixTokens -or $All) {
    Fix-TokenIssues
}

if (-not ($Initialize -or $Validate -or $FixTokens -or $All)) {
    Write-ColorMessage "Please specify an operation: -Initialize, -Validate, -FixTokens, or -All" $colors.Warning
    Write-ColorMessage "Example: .\Setup-AutogenEnvironment.ps1 -Initialize" $colors.Info
}

