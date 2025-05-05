# Security.psm1
# Security and token management functions for AutoGen

#Requires -Version 7.0

using module .\Common.psm1

<#
.SYNOPSIS
    Scans files for potential tokens or secrets.
.DESCRIPTION
    Checks specified files for patterns that might indicate hardcoded secrets or tokens.
.PARAMETER FilePaths
    The files to scan.
.PARAMETER TokenPatterns
    Regular expression patterns for detecting tokens.
.EXAMPLE
    $issues = Find-ExposedTokens -FilePaths @(".vscode/settings.json")
#>
function Find-ExposedTokens {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$FilePaths,

        [Parameter()]
        [string[]]$TokenPatterns = @(
            'ghp_[a-zA-Z0-9]{36}',                                     # GitHub personal access token
            'github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}',              # GitHub fine-grained PAT
            'sk-[a-zA-Z0-9]{48}',                                      # OpenAI API key
            'key-[a-zA-Z0-9]{24}',                                     # Generic API key format
            'xoxb-[a-zA-Z0-9\-]{50,}',                                 # Slack token
            '[a-zA-Z0-9\-]{24}\.[a-zA-Z0-9\-]{6}\.[a-zA-Z0-9\-]{27}',  # JWT-like tokens
            '[A-Za-z0-9+/]{88}==',                                     # Base64 encoded secrets
            'AKIA[0-9A-Z]{16}',                                        # AWS access key
            '-----BEGIN [A-Z ]+ PRIVATE KEY-----'                      # Private key
        )
    )

    $issues = @()

    foreach ($file in $FilePaths) {
        if (-not (Test-Path -Path $file)) {
            Write-LogMessage "File not found: $file" "WARNING"
            continue
        }

        try {
            $content = Get-Content -Path $file -Raw

            foreach ($pattern in $TokenPatterns) {
                if ($content -match $pattern) {
                    $match = $Matches[0]
                    $maskedMatch = $match.Substring(0, [Math]::Min(4, $match.Length)) + "..." + $match.Substring([Math]::Max(0, $match.Length - 4))

                    $issues += [PSCustomObject]@{
                        File = $file
                        Pattern = $pattern
                        Excerpt = $maskedMatch
                        LineNumber = ($content.Substring(0, $content.IndexOf($match)).Split("`n").Length)
                    }

                    Write-LogMessage "Found potential token in $file matching pattern $pattern" "WARNING"
                }
            }

            # Check for direct environment variable assignments with no reference
            # This pattern detects assignments like "TOKEN": "abc123" but not "TOKEN": "${env:VAR}"
            if ($content -match '"[A-Z_]+":\s*"[^$][^{][^"]*"') {
                $match = $Matches[0]

                $issues += [PSCustomObject]@{
                    File = $file
                    Pattern = "Direct environment variable assignment"
                    Excerpt = $match
                    LineNumber = ($content.Substring(0, $content.IndexOf($match)).Split("`n").Length)
                }

                Write-LogMessage "Found direct environment variable assignment in $file" "WARNING"
            }
        } catch {
            Write-LogMessage "Error scanning $file for tokens: $_" "ERROR"
        }
    }

    return $issues
}

<#
.SYNOPSIS
    Scans repository for sensitive data.
.DESCRIPTION
    Performs a comprehensive scan of the repository for sensitive information.
.PARAMETER RepositoryPath
    The path to the repository.
.EXAMPLE
    Invoke-RepositoryScan -RepositoryPath "C:\Projects\autogen"
#>
function Invoke-RepositoryScan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RepositoryPath
    )

    Write-SectionHeader "Repository Security Scan"

    # Define high-risk file patterns
    $highRiskPatterns = @(
        "*.env",
        "*.key",
        "*.pem",
        "*secret*",
        "*token*",
        "*password*",
        "*.pfx",
        "*.p12",
        "*credentials*"
    )

    # Define high-risk directories to search
    $directoriesToSearch = @(
        ".vscode",
        ".github",
        "config",
        "settings"
    )

    $highRiskFiles = @()

    # Search for high-risk files
    Write-MessageWithColor "Scanning for high-risk file patterns..." $Colors.Info
    foreach ($pattern in $highRiskPatterns) {
        $matchingFiles = Get-ChildItem -Path $RepositoryPath -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue
        $highRiskFiles += $matchingFiles
    }

    # Search specific directories
    foreach ($dir in $directoriesToSearch) {
        $dirPath = Join-Path -Path $RepositoryPath -ChildPath $dir
        if (Test-Path -Path $dirPath -PathType Container) {
            $configFiles = Get-ChildItem -Path $dirPath -Filter "*.json" -File -Recurse -ErrorAction SilentlyContinue
            $highRiskFiles += $configFiles
        }
    }

    # Deduplicate files
    $uniqueFiles = $highRiskFiles | Select-Object -Property FullName -Unique

    if (-not $uniqueFiles) {
        Write-StatusMessage "No high-risk files found" "Success" 2
        return @()
    }

    Write-StatusMessage "Found $($uniqueFiles.Count) high-risk files to scan" "Info" 2

    # Scan each file for tokens
    $allIssues = @()
    foreach ($file in $uniqueFiles) {
        Write-StatusMessage "Scanning $($file.FullName)" "Pending" 4
        $fileIssues = Find-ExposedTokens -FilePaths @($file.FullName)

        if ($fileIssues.Count -gt 0) {
            Write-StatusMessage "$($fileIssues.Count) potential issue(s) found in $($file.FullName)" "Warning" 4
            $allIssues += $fileIssues
        } else {
            Write-StatusMessage "No issues found in $($file.FullName)" "Success" 4
        }
    }

    if ($allIssues.Count -gt 0) {
        Write-MessageWithColor "`nFound $($allIssues.Count) potential security issue(s):" $Colors.Warning
        $allIssues | ForEach-Object {
            Write-MessageWithColor "  - $($_.File) (line $($_.LineNumber)): $($_.Pattern)" $Colors.Warning
        }
    } else {
        Write-MessageWithColor "`nNo security issues found in scanned files." $Colors.Success
    }

    return $allIssues
}

<#
.SYNOPSIS
    Fixes token usage in configuration files.
.DESCRIPTION
    Replaces hardcoded tokens with environment variable references.
.PARAMETER FilePath
    The path to the file to fix.
.PARAMETER BackupFile
    Whether to create a backup of the original file.
.EXAMPLE
    Repair-TokenUsage -FilePath ".vscode/settings.json"
#>
function Repair-TokenUsage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter()]
        [switch]$BackupFile = $true
    )

    if (-not (Test-Path -Path $FilePath)) {
        Write-LogMessage "File not found: $FilePath" "ERROR"
        return $false
    }

    try {
        if ($BackupFile) {
            Backup-File -FilePath $FilePath
        }

        $content = Get-Content -Path $FilePath -Raw
        $originalContent = $content
        $modified = $false

        # Define replacement patterns
        $replacements = @{
            # GitHub token patterns
            '"GITHUB_PERSONAL_ACCESS_TOKEN"\s*:\s*"([^$][^"]*)"' = '"GITHUB_PERSONAL_ACCESS_TOKEN": "${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"'
            '"githubToken"\s*:\s*"([^$][^"]*)"' = '"githubToken": "${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"'
            '"token"\s*:\s*"([^$][^"]*)"' = '"token": "${env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"'

            # OpenAI token patterns
            '"OPENAI_API_KEY"\s*:\s*"([^$][^"]*)"' = '"OPENAI_API_KEY": "${env:OPENAI_API_KEY}"'
            '"apiKey"\s*:\s*"([^$][^"]*)"' = '"apiKey": "${env:OPENAI_API_KEY}"'

            # HuggingFace token patterns
            '"HF_TOKEN"\s*:\s*"([^$][^"]*)"' = '"HF_TOKEN": "${env:FORK_HUGGINGFACE_ACCESS_TOKEN}"'
            '"huggingfaceToken"\s*:\s*"([^$][^"]*)"' = '"huggingfaceToken": "${env:FORK_HUGGINGFACE_ACCESS_TOKEN}"'
        }

        foreach ($pattern in $replacements.Keys) {
            if ($content -match $pattern) {
                $content = $content -replace $pattern, $replacements[$pattern]
                $modified = $true
                Write-LogMessage "Replaced token pattern $pattern in $FilePath" "INFO"
            }
        }

        if ($modified) {
            Set-Content -Path $FilePath -Value $content
            Write-StatusMessage "Updated $FilePath to use environment variables" "Success" 2
            return $true
        } else {
            Write-StatusMessage "No changes needed in $FilePath" "Info" 2
            return $false
        }
    } catch {
        Write-LogMessage "Error repairing token usage in $FilePath: $_" "ERROR"
        return $false
    }
}

<#
.SYNOPSIS
    Verifies GitHub repository secrets.
.DESCRIPTION
    Checks if required secrets are set in the GitHub repository.
.PARAMETER Owner
    The GitHub repository owner.
.PARAMETER Repo
    The GitHub repository name.
.PARAMETER Token
    The GitHub personal access token.
.EXAMPLE
    Test-GitHubSecrets -Owner "username" -Repo "autogen"
#>
function Test-GitHubSecrets {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$Repo,

        [Parameter()]
        [string]$Token = $env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN
    )

    Write-SectionHeader "Checking GitHub Repository Secrets"

    if (-not $Token) {
        Write-LogMessage "GitHub token not provided or empty" "ERROR"
        Write-StatusMessage "GitHub Personal Access Token not available" "Error" 2
        return $false
    }

    try {
        $headers = @{
            Authorization = "token $Token"
            Accept = "application/vnd.github.v3+json"
        }

        # We can't directly get the list of secrets due to GitHub API limitations,
        # but we can get the public keys for the repo, which indicates the repo can use secrets
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/actions/secrets/public-key" -Headers $headers -Method Get

        Write-StatusMessage "Successfully connected to GitHub API" "Success" 2
        Write-StatusMessage "Repository exists and has secrets configured" "Success" 2

        Write-MessageWithColor "`nTo set required secrets, visit:" $Colors.Info
        Write-MessageWithColor "https://github.com/$Owner/$Repo/settings/secrets/actions" $Colors.Info

        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        if ($statusCode -eq 404) {
            Write-StatusMessage "Repository not found or you don't have access to it" "Error" 2
        } elseif ($statusCode -eq 401) {
            Write-StatusMessage "Authentication failed. Check your personal access token" "Error" 2
        } else {
            Write-StatusMessage "Error checking GitHub secrets: $_" "Error" 2
        }

        return $false
    }
}

# Export module members
Export-ModuleMember -Function Find-ExposedTokens
Export-ModuleMember -Function Invoke-RepositoryScan
Export-ModuleMember -Function Repair-TokenUsage
Export-ModuleMember -Function Test-GitHubSecrets
