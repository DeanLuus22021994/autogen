# VSCode.psm1
# VS Code integration and configuration functions for AutoGen

#Requires -Version 7.0

using module .\Common.psm1
using module .\Security.psm1

<#
.SYNOPSIS
    Tests VS Code configuration files for security issues.
.DESCRIPTION
    Scans VS Code settings and configuration files for exposed secrets or tokens.
.PARAMETER ConfigDirectory
    Directory containing VS Code configuration (defaults to .vscode).
.PARAMETER AdditionalPatterns
    Additional token patterns to check beyond the default ones.
.EXAMPLE
    Test-VSCodeConfigSecurity -ConfigDirectory ".vscode"
#>
function Test-VSCodeConfigSecurity {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$ConfigDirectory = ".vscode",

        [Parameter()]
        [string[]]$AdditionalPatterns
    )

    Write-SectionHeader "VS Code Configuration Security Check"

    $configPath = Join-Path $PWD $ConfigDirectory

    if (-not (Test-Path $configPath)) {
        Write-StatusMessage "VS Code configuration directory not found: $ConfigDirectory" "Warning" 0
        return $false
    }

    # VS Code files to check
    $vsCodeFiles = @(
        "extensions.json",
        "launch.json",
        "mcp.json",
        "settings.json",
        "tasks.json"
    )

    $allFiles = @()
    foreach ($file in $vsCodeFiles) {
        $filePath = Join-Path $configPath $file
        if (Test-Path $filePath) {
            $allFiles += $filePath
        }
    }

    if ($allFiles.Count -eq 0) {
        Write-StatusMessage "No VS Code configuration files found to check" "Warning" 0
        return $true
    }

    # Combine patterns
    $patterns = $AdditionalPatterns

    # Perform the security scan
    $issues = Find-ExposedTokens -FilePaths $allFiles -TokenPatterns $patterns

    if ($issues.Count -gt 0) {
        Write-StatusMessage "Found potential security issues in VS Code configuration:" "Error" 0
        foreach ($issue in $issues) {
            Write-StatusMessage "$($issue.File): $($issue.Issue)" "Error" 1
        }
        return $false
    }
    else {
        Write-StatusMessage "No security issues found in VS Code configuration" "Success" 0
        return $true
    }
}

<#
.SYNOPSIS
    Updates VS Code configuration to use environment variables.
.DESCRIPTION
    Modifies VS Code configuration files to use environment variables for secrets.
.PARAMETER ConfigDirectory
    Directory containing VS Code configuration (defaults to .vscode).
.PARAMETER TokenMappings
    Mapping of token patterns to environment variable names.
.EXAMPLE
    Update-VSCodeConfigSecurely -ConfigDirectory ".vscode"
#>
function Update-VSCodeConfigSecurely {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$ConfigDirectory = ".vscode",

        [Parameter()]
        [hashtable]$TokenMappings = @{
            '"GITHUB_PERSONAL_ACCESS_TOKEN"\s*:\s*"([^$][^"]*)"' = '"GITHUB_PERSONAL_ACCESS_TOKEN": "${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"';
            '"token"\s*:\s*"([^$][^"]*)"' = '"token": "${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"';
            '"githubToken"\s*:\s*"([^$][^"]*)"' = '"githubToken": "${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"';
            '"OPENAI_API_KEY"\s*:\s*"([^$][^"]*)"' = '"OPENAI_API_KEY": "${env:OPENAI_API_KEY}"';
            '"HF_TOKEN"\s*:\s*"([^$][^"]*)"' = '"HF_TOKEN": "${env:FORK_HUGGINGFACE_ACCESS_TOKEN}"';
        }
    )

    Write-SectionHeader "Updating VS Code Configuration"

    $configPath = Join-Path $PWD $ConfigDirectory

    if (-not (Test-Path $configPath)) {
        Write-StatusMessage "VS Code configuration directory not found: $ConfigDirectory" "Warning" 0
        return $false
    }

    # VS Code files to check
    $vsCodeFiles = @(
        "mcp.json",
        "settings.json",
        "launch.json"
    )

    $changesApplied = $false

    foreach ($file in $vsCodeFiles) {
        $filePath = Join-Path $configPath $file
        if (Test-Path $filePath) {
            $content = Get-Content $filePath -Raw
            $originalContent = $content
            $fileChanged = $false

            # Apply each replacement pattern
            foreach ($pattern in $TokenMappings.Keys) {
                $replacement = $TokenMappings[$pattern]
                $newContent = $content -replace $pattern, $replacement

                if ($newContent -ne $content) {
                    $content = $newContent
                    $fileChanged = $true
                }
            }

            # Update the file if changes were made
            if ($fileChanged) {
                Set-Content -Path $filePath -Value $content
                Write-StatusMessage "Updated $file to use environment variables" "Success" 1
                $changesApplied = $true
            }
            else {
                Write-StatusMessage "No changes needed in $file" "Info" 1
            }
        }
    }

    if ($changesApplied) {
        Write-StatusMessage "VS Code configuration updated successfully" "Success" 0
        return $true
    }
    else {
        Write-StatusMessage "No changes were needed in VS Code configuration" "Info" 0
        return $true
    }
}

<#
.SYNOPSIS
    Ensures VS Code settings are properly configured for AutoGen development.
.DESCRIPTION
    Sets up VS Code settings for Python, linting, and other development tools.
.PARAMETER PythonPath
    Path to the Python interpreter to use.
.PARAMETER UpdateWorkspaceSettings
    Update workspace-specific settings.
.EXAMPLE
    Initialize-VSCodeEnvironment -PythonPath "c:\Projects\autogen\.venv\Scripts\python.exe"
#>
function Initialize-VSCodeEnvironment {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$PythonPath = "$PWD\.venv\Scripts\python.exe",

        [Parameter()]
        [switch]$UpdateWorkspaceSettings
    )

    Write-SectionHeader "VS Code Environment Setup"

    # Ensure .vscode directory exists
    $vscodeDir = Join-Path $PWD ".vscode"
    if (-not (Test-Path $vscodeDir)) {
        New-Item -ItemType Directory -Path $vscodeDir | Out-Null
        Write-StatusMessage "Created .vscode directory" "Success" 1
    }

    # Create default settings if they don't exist
    $settingsPath = Join-Path $vscodeDir "settings.json"

    if (-not (Test-Path $settingsPath) -or $UpdateWorkspaceSettings) {
        # Convert paths to use forward slashes for VS Code
        $pythonPathForVSCode = $PythonPath.Replace('\', '/')
        $repoPathForVSCode = $PWD.ToString().Replace('\', '/')

        $settingsContent = @"
{
    "python.defaultInterpreterPath": "$pythonPathForVSCode",
    "python.analysis.extraPaths": [
        "$repoPathForVSCode/python"
    ],
    "python.linting.enabled": true,
    "python.linting.mypyEnabled": true,
    "python.analysis.typeCheckingMode": "basic",
    "ruff.path": ["$pythonPathForVSCode\..\ruff.exe"],
    "ruff.interpreter": ["$pythonPathForVSCode"],
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.organizeImports": "explicit"
    },
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "files.trimFinalNewlines": true
}
"@

        Set-Content -Path $settingsPath -Value $settingsContent
        Write-StatusMessage "Created/updated VS Code settings.json" "Success" 1
    }
    else {
        Write-StatusMessage "VS Code settings.json already exists" "Info" 1
    }

    # Create extensions.json if it doesn't exist
    $extensionsPath = Join-Path $vscodeDir "extensions.json"

    if (-not (Test-Path $extensionsPath)) {
        $extensionsContent = @"
{
    "recommendations": [
        "charliermarsh.ruff",
        "matangover.mypy",
        "ms-python.python",
        "ms-python.vscode-pylance",
        "github.vscode-github-actions",
        "davidanson.vscode-markdownlint",
        "redhat.vscode-yaml"
    ]
}
"@

        Set-Content -Path $extensionsPath -Value $extensionsContent
        Write-StatusMessage "Created VS Code extensions.json" "Success" 1
    }
    else {
        Write-StatusMessage "VS Code extensions.json already exists" "Info" 1
    }

    # Create tasks.json if it doesn't exist
    $tasksPath = Join-Path $vscodeDir "tasks.json"

    if (-not (Test-Path $tasksPath)) {
        $tasksContent = @"
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Validate Environment Variables",
            "type": "shell",
            "command": "pwsh -File \".scripts\\automation\\github\\orchestration\\Validate-Environment.ps1\"",
            "group": {
                "kind": "test",
                "isDefault": true
            }
        },
        {
            "label": "Fix Security Issues",
            "type": "shell",
            "command": "pwsh -File \".scripts\\automation\\github\\orchestration\\Repair-SecurityIssues.ps1\"",
            "problemMatcher": []
        },
        {
            "label": "Commit VS Code Config",
            "type": "shell",
            "command": "pwsh -File \".scripts\\automation\\github\\orchestration\\Commit-VSCodeConfig.ps1\"",
            "problemMatcher": []
        },
        {
            "label": "Verify GitHub Setup",
            "type": "shell",
            "command": "pwsh -File \".scripts\\automation\\github\\orchestration\\Verify-GitHubSetup.ps1\"",
            "problemMatcher": []
        }
    ]
}
"@

        Set-Content -Path $tasksPath -Value $tasksContent
        Write-StatusMessage "Created VS Code tasks.json" "Success" 1
    }
    else {
        Write-StatusMessage "VS Code tasks.json already exists" "Info" 1
    }

    Write-StatusMessage "VS Code environment setup complete" "Success" 0
    return $true
}

Export-ModuleMember -Function Test-VSCodeConfigSecurity, Update-VSCodeConfigSecurely, Initialize-VSCodeEnvironment
