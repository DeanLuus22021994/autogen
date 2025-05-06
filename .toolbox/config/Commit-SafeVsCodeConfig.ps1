#!/usr/bin/env pwsh
# Commit-SafeVsCodeConfig.ps1
# This script safely commits VS Code configuration files after ensuring no tokens are exposed

param (
    [switch]$Force,
    [string]$Message = "chore: update VS Code configuration files"
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

function Test-VsCodeConfigSafety {
    Write-ColorMessage "Checking VS Code configuration files for exposed secrets..." $colors.Info
    $issues = $false

    # VS Code files to check
    $vsCodeFiles = @(
        ".vscode\extensions.json",
        ".vscode\launch.json",
        ".vscode\mcp.json",
        ".vscode\settings.json",
        ".vscode\tasks.json"
    )

    $tokenPatterns = @(
        'ghp_[a-zA-Z0-9]{36}',
        'github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}',
        'sk-[a-zA-Z0-9]{48}',
        'key-[a-zA-Z0-9]{24}',
        'xoxb-[a-zA-Z0-9\-]{50,}',
        '[a-zA-Z0-9\-]{24}\.[a-zA-Z0-9\-]{6}\.[a-zA-Z0-9\-]{27}', # JWT-like tokens
        '[A-Za-z0-9+/]{88}=='  # Base64 encoded secrets pattern
    )

    foreach ($file in $vsCodeFiles) {
        $filePath = Join-Path $pwd $file
        if (Test-Path $filePath) {
            Write-ColorMessage "  Checking $file" $colors.Info
            $content = Get-Content $filePath -Raw

            foreach ($pattern in $tokenPatterns) {
                if ($content -match $pattern) {
                    Write-ColorMessage "    ❌ Found potential token in $file" $colors.Error
                    $issues = $true
                }
            }

            # Check for direct environment variable assignment
            if ($content -match '"[A-Z_]+":\s*"[^$][^{][^"]*"') {
                Write-ColorMessage "    ⚠️ Found direct environment variable assignment in $file" $colors.Warning
                $issues = $true
            }
        }
    }

    return -not $issues
}

function Fix-VsCodeConfigIssues {
    Write-ColorMessage "Fixing VS Code configuration files to use environment variables..." $colors.Info

    # Specifically check and fix mcp.json
    $mpcJsonPath = Join-Path $pwd ".vscode\mcp.json"
    if (Test-Path $mpcJsonPath) {
        $content = Get-Content $mpcJsonPath -Raw

        # Replace any direct token references with environment variable reference
        $updated = $content -replace '"GITHUB_PERSONAL_ACCESS_TOKEN"\s*:\s*"([^$][^"]*)"', '"GITHUB_PERSONAL_ACCESS_TOKEN": "${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"'

        if ($updated -ne $content) {
            Set-Content -Path $mpcJsonPath -Value $updated
            Write-ColorMessage "  ✅ Updated .vscode\mcp.json to use environment variables" $colors.Success
        }
    }

    # Check other VS Code files that might contain tokens
    $settingsJsonPath = Join-Path $pwd ".vscode\settings.json"
    if (Test-Path $settingsJsonPath) {
        $content = Get-Content $settingsJsonPath -Raw

        # Replace any token patterns with environment variable references
        $patterns = @{
            '"token"\s*:\s*"([^$][^"]*)"' = '"token": "${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"';
            '"githubToken"\s*:\s*"([^$][^"]*)"' = '"githubToken": "${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"';
            '"OPENAI_API_KEY"\s*:\s*"([^$][^"]*)"' = '"OPENAI_API_KEY": "${env:OPENAI_API_KEY}"';
            '"HF_TOKEN"\s*:\s*"([^$][^"]*)"' = '"HF_TOKEN": "${env:FORK_HUGGINGFACE_ACCESS_TOKEN}"';
        }

        $updated = $content
        foreach ($pattern in $patterns.Keys) {
            $updated = $updated -replace $pattern, $patterns[$pattern]
        }

        if ($updated -ne $content) {
            Set-Content -Path $settingsJsonPath -Value $updated
            Write-ColorMessage "  ✅ Updated .vscode\settings.json to use environment variables" $colors.Success
        }
    }
}

function Commit-VsCodeFiles {
    param (
        [string]$CommitMessage
    )

    Write-ColorMessage "Committing VS Code configuration files..." $colors.Info

    # Files to commit
    $vsCodeFiles = @(
        ".vscode\extensions.json",
        ".vscode\launch.json",
        ".vscode\mcp.json",
        ".vscode\settings.json",
        ".vscode\tasks.json"
    )

    # Add each file if it exists
    foreach ($file in $vsCodeFiles) {
        $filePath = Join-Path $pwd $file
        if (Test-Path $filePath) {
            git add $filePath
            Write-ColorMessage "  Added $file to commit" $colors.Success
        }
    }

    # Commit the files
    git commit -m $CommitMessage
    Write-ColorMessage "Changes committed with message: $CommitMessage" $colors.Success
}

# Main script execution
if ($Force) {
    Fix-VsCodeConfigIssues
    Commit-VsCodeFiles -CommitMessage $Message
} else {
    $safe = Test-VsCodeConfigSafety

    if (-not $safe) {
        Write-ColorMessage "Issues found in VS Code configuration files." $colors.Error
        $fix = Read-Host "Do you want to attempt to fix these issues? (y/n)"

        if ($fix -eq "y") {
            Fix-VsCodeConfigIssues
            $safe = Test-VsCodeConfigSafety
        }
    }

    if ($safe) {
        Write-ColorMessage "VS Code configuration files are safe to commit." $colors.Success
        $commit = Read-Host "Do you want to commit these files now? (y/n)"

        if ($commit -eq "y") {
            Commit-VsCodeFiles -CommitMessage $Message
        }
    } else {
        Write-ColorMessage "Please fix the issues manually before committing." $colors.Error
        Write-ColorMessage "Use the -Force switch to override this check (not recommended)." $colors.Warning
    }
}
