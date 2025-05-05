# Repair-SecurityIssues.ps1
# Identifies and fixes security issues in the repository

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

function Repair-SecurityIssues {
    Write-Host ""
    Write-SectionHeader "AutoGen Security Repair"
    Write-StatusMessage "Starting security repair process..." "Info" 0

    # Check sensitive files in repository
    $sensitiveFilesPattern = @(
        "*.env",
        ".env.*",
        "*.token",
        "*.key",
        "*.pem",
        "*_rsa",
        "*.ppk"
    )

    Write-StatusMessage "Checking for sensitive files in repository..." "Info" 0

    $sensitiveFiles = @()
    foreach ($pattern in $sensitiveFilesPattern) {
        $files = Get-ChildItem -Path $PWD -Filter $pattern -Recurse -ErrorAction SilentlyContinue -Force
        $sensitiveFiles += $files
    }

    if ($sensitiveFiles.Count -gt 0) {
        Write-StatusMessage "Found $($sensitiveFiles.Count) sensitive files in repository:" "Warning" 0
        foreach ($file in $sensitiveFiles) {
            Write-StatusMessage "  $($file.FullName.Replace($PWD.ToString(), '.'))" "Warning" 1
        }

        $response = Read-Host "Would you like to add these files to .gitignore? (Y/N)"
        if ($response -eq "Y" -or $response -eq "y") {
            # Create or update .gitignore
            $gitignorePath = Join-Path $PWD ".gitignore"

            if (-not (Test-Path $gitignorePath)) {
                New-Item -ItemType File -Path $gitignorePath -Force | Out-Null
                Write-StatusMessage "Created .gitignore file" "Success" 1
            }

            $gitignoreContent = Get-Content $gitignorePath -Raw -ErrorAction SilentlyContinue
            if (-not $gitignoreContent) {
                $gitignoreContent = ""
            }

            $gitignoreContent += "`n# Added by AutoGen security script`n"

            foreach ($pattern in $sensitiveFilesPattern) {
                if (-not ($gitignoreContent -match [regex]::Escape($pattern))) {
                    $gitignoreContent += "$pattern`n"
                }
            }

            Set-Content -Path $gitignorePath -Value $gitignoreContent
            Write-StatusMessage "Updated .gitignore with sensitive file patterns" "Success" 1
        }
    }
    else {
        Write-StatusMessage "No sensitive files found in repository" "Success" 0
    }

    # Check VS Code settings for hardcoded tokens
    Write-StatusMessage "Checking VS Code settings for exposed tokens..." "Info" 0
    $configSecurity = Test-VSCodeConfigSecurity

    if (-not $configSecurity) {
        $response = Read-Host "Would you like to update VS Code settings to use environment variables instead of hardcoded tokens? (Y/N)"
        if ($response -eq "Y" -or $response -eq "y") {
            $updated = Update-VSCodeConfigSecurely

            if ($updated) {
                Write-StatusMessage "VS Code settings updated to use environment variables" "Success" 1
            }
            else {
                Write-StatusMessage "Failed to update VS Code settings" "Error" 1
            }
        }
    }
    else {
        Write-StatusMessage "VS Code configuration is secure" "Success" 0
    }

    # Scan for exposed tokens in code files
    Write-StatusMessage "Scanning repository for exposed tokens..." "Info" 0

    $fileTypes = @("*.ps1", "*.py", "*.js", "*.ts", "*.json", "*.md", "*.ipynb")
    $filesToScan = @()

    foreach ($type in $fileTypes) {
        $files = Get-ChildItem -Path $PWD -Filter $type -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch "\\node_modules\\" -and $_.FullName -notmatch "\\.git\\" }
        $filesToScan += $files.FullName
    }

    $exposedTokens = Find-ExposedTokens -FilePaths $filesToScan

    if ($exposedTokens.Count -gt 0) {
        Write-StatusMessage "Found potential exposed tokens in $($exposedTokens.Count) files:" "Warning" 0
        foreach ($issue in $exposedTokens) {
            Write-StatusMessage "$($issue.File): $($issue.Issue)" "Warning" 1
        }

        Write-StatusMessage "Please review these files and replace any hardcoded tokens with environment variables" "Info" 0
        Write-StatusMessage "After fixing, you may need to use git-filter-repo or BFG Repo-Cleaner to remove tokens from history" "Info" 0

        $response = Read-Host "Would you like to clean repository history for these files? (warning: this will rewrite git history) (Y/N)"
        if ($response -eq "Y" -or $response -eq "y") {
            $filesToRemove = $exposedTokens | ForEach-Object { $_.File } | Select-Object -Unique
            $result = Remove-SensitiveDataFromHistory -FilesToRemove $filesToRemove

            if ($result) {
                Write-StatusMessage "Repository history cleaned for sensitive files" "Success" 1
                Write-StatusMessage "You will need to force push changes: git push --force" "Warning" 1
            }
            else {
                Write-StatusMessage "Failed to clean repository history" "Error" 1
            }
        }
    }
    else {
        Write-StatusMessage "No exposed tokens found in code files" "Success" 0
    }

    # Output overall status
    Write-Host ""
    Write-StatusMessage "Security repair process completed" "Success" 0
    Write-StatusMessage "Remember to regularly check for security issues with the 'Validate Environment' task" "Info" 0
    Write-Host ""
}

# Run the repair process
Repair-SecurityIssues
