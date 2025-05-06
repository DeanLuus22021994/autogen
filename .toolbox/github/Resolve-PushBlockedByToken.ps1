# Resolve-PushBlockedByToken.ps1
# This script helps resolve the GitHub push protection issue due to detected tokens

param (
    [switch]$Fix,
    [switch]$Unblock,
    [string]$UnblockURL
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

function Fix-TokenIssue {
    Write-ColorMessage "Fixing token issue in repository..." $colors.Info

    # Check the mcp.json file for GitHub tokens
    $mpcJsonPath = Join-Path $pwd ".vscode\mcp.json"

    if (Test-Path $mpcJsonPath) {
        $content = Get-Content $mpcJsonPath -Raw

        # Replace any direct token references with environment variable reference
        $updated = $content -replace '"GITHUB_PERSONAL_ACCESS_TOKEN"\s*:\s*"([^$][^"]*)"', '"GITHUB_PERSONAL_ACCESS_TOKEN": "${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"'

        if ($updated -ne $content) {
            Set-Content -Path $mpcJsonPath -Value $updated
            Write-ColorMessage "  ✅ Updated .vscode\mcp.json to use environment variables" $colors.Success
        } else {
            Write-ColorMessage "  ✅ .vscode\mcp.json is already using environment variables" $colors.Success
        }
    } else {
        Write-ColorMessage "  ❓ .vscode\mcp.json not found" $colors.Warning
    }

    # Create a commit for the fix
    git add .vscode\mcp.json
    git commit -m "fix: replace direct token with environment variable reference"

    Write-ColorMessage "Changes committed. You can now try pushing again." $colors.Success
}

function Unblock-Secret {
    param (
        [string]$URL
    )

    Write-ColorMessage "Unblocking secret using provided URL..." $colors.Info

    if (-not $URL) {
        Write-ColorMessage "Please provide the unblock URL from the error message using -UnblockURL parameter" $colors.Error
        return
    }

    # Open the URL in the default browser
    Start-Process $URL

    Write-ColorMessage "Browser opened with the unblock URL. Follow these steps:" $colors.Warning
    Write-ColorMessage "1. Log in to GitHub if prompted" $colors.Info
    Write-ColorMessage "2. Select 'I understand and want to proceed with pushing this secret'" $colors.Info
    Write-ColorMessage "3. Click 'Allow'" $colors.Info
    Write-ColorMessage "4. Return to your terminal and run 'git push' again" $colors.Info

    Write-ColorMessage "NOTE: This should only be used for tokens that are no longer valid or were test tokens" $colors.Warning
    Write-ColorMessage "Best practice is to fix the issue by removing the token from the file instead" $colors.Warning
}

function Show-Instructions {
    Write-ColorMessage "GitHub Push Protection Issues - Resolution Guide" $colors.Info
    Write-ColorMessage "===============================================" $colors.Info
    Write-ColorMessage ""

    Write-ColorMessage "You have two options to resolve this issue:" $colors.Warning

    Write-ColorMessage "Option 1: Fix the token issue in the repository" $colors.Success
    Write-ColorMessage "  This is the recommended approach. It will:"
    Write-ColorMessage "  - Replace direct token references with environment variable references"
    Write-ColorMessage "  - Commit the changes"
    Write-ColorMessage "  - Allow you to push again"
    Write-ColorMessage "  Run: .\Resolve-PushBlockedByToken.ps1 -Fix" $colors.Info
    Write-ColorMessage ""

    Write-ColorMessage "Option 2: Unblock the secret (only if the token is already revoked)" $colors.Warning
    Write-ColorMessage "  Use this only if the token is no longer valid or was a test token"
    Write-ColorMessage "  Run: .\Resolve-PushBlockedByToken.ps1 -Unblock -UnblockURL 'https://github.com/...'" $colors.Info
    Write-ColorMessage "  (Replace the URL with the one from your error message)" $colors.Info
    Write-ColorMessage ""

    Write-ColorMessage "For a more comprehensive solution:" $colors.Info
    Write-ColorMessage "1. Run .\Setup-GitSecureEnvironment.ps1 -SetupGit to configure Git securely" $colors.Info
    Write-ColorMessage "2. Run .\Setup-GitSecureEnvironment.ps1 -CleanHistory to clean sensitive data from history" $colors.Info
    Write-ColorMessage "3. Run .\Validate-EnvSecrets.ps1 -Setup to ensure all environment variables are set" $colors.Info
}

# Main script execution
if ($Fix) {
    Fix-TokenIssue
} elseif ($Unblock) {
    Unblock-Secret -URL $UnblockURL
} else {
    Show-Instructions
}
