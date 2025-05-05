# Environment.psm1
# Environment management functions for AutoGen

#Requires -Version 7.0

using module .\Common.psm1

<#
.SYNOPSIS
    Validates required environment variables.
.DESCRIPTION
    Checks if all required environment variables are set and provides feedback.
.PARAMETER RequiredVariables
    The list of required environment variable names.
.EXAMPLE
    Test-EnvironmentVariables @("REPO_PATH", "FORK_AUTOGEN_OWNER")
#>
function Test-EnvironmentVariables {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$RequiredVariables,

        [Parameter()]
        [switch]$Optional
    )

    if (-not $Optional) {
        Write-SectionHeader "Environment Variable Validation"
    } else {
        Write-SectionHeader "Optional Environment Variable Check"
    }

    $missingVariables = @()

    foreach ($variable in $RequiredVariables) {
        if (-not (Get-Item "env:$variable" -ErrorAction SilentlyContinue)) {
            if (-not $Optional) {
                Write-StatusMessage "$variable is not set" "Error" 2
            } else {
                Write-StatusMessage "$variable is not set" "Warning" 2
            }
            $missingVariables += $variable
        } else {
            Write-StatusMessage "$variable is properly set" "Success" 2
        }
    }    if ($missingVariables.Count -gt 0) {
        if (-not $Optional) {
            Write-MessageWithColor "`nThe following environment variables are missing:" $Colors.Warning
            foreach ($var in $missingVariables) {
                Write-MessageWithColor "  - $var" $Colors.Warning
            }
            return $false
        } else {
            Write-MessageWithColor "`nThe following optional environment variables are not set:" $Colors.Muted
            foreach ($var in $missingVariables) {
                Write-MessageWithColor "  - $var" $Colors.Muted
            }
            return $true
        }
    }

    if (-not $Optional) {
        Write-MessageWithColor "`nAll required environment variables are set." $Colors.Success
    } else {
        Write-MessageWithColor "`nAll optional environment variables are set." $Colors.Success
    }
    return $true
}

<#
.SYNOPSIS
    Sets environment variables at the user or machine level.
.DESCRIPTION
    Prompts for and permanently sets environment variables at the user or machine level.
.PARAMETER Variables
    The list of environment variable names to set.
.PARAMETER Scope
    The scope at which to set the variables (User or Machine).
.EXAMPLE
    Set-PermanentEnvironmentVariables @("REPO_PATH", "FORK_AUTOGEN_OWNER") "User"
#>
function Set-PermanentEnvironmentVariables {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Variables,

        [Parameter()]
        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"
    )

    if ($Scope -eq "Machine" -and -not (Test-AdminPrivileges)) {
        Write-MessageWithColor "Administrator privileges required to set machine-level environment variables." $Colors.Error
        return $false
    }

    Write-SectionHeader "Setting Environment Variables"

    foreach ($var in $Variables) {
        $currentValue = [Environment]::GetEnvironmentVariable($var, $Scope)
        $prompt = "Enter value for $var"
        if ($currentValue) {
            $prompt += " (current: $currentValue)"
        }
        $prompt += ":"

        $value = Read-Host -Prompt $prompt

        if ([string]::IsNullOrWhiteSpace($value)) {
            if ($currentValue) {
                Write-StatusMessage "Keeping existing value for $var" "Info" 2
            } else {
                Write-StatusMessage "Skipped setting $var" "Warning" 2
            }
            continue
        }

        [Environment]::SetEnvironmentVariable($var, $value, $Scope)
        [Environment]::SetEnvironmentVariable($var, $value, "Process")
        Write-StatusMessage "Set $var at $Scope level" "Success" 2
    }

    Write-MessageWithColor "`nEnvironment variables have been set. Some applications may need to be restarted to recognize these changes." $Colors.Info
    return $true
}

<#
.SYNOPSIS
    Creates or updates the .env file with environment values.
.DESCRIPTION
    Generates a .env file with environment variable references, avoiding storing actual secrets.
.PARAMETER OutputPath
    The path where the .env file should be created.
.PARAMETER IncludeSecrets
    If specified, includes placeholder comments for secrets.
.EXAMPLE
    Update-DotEnvFile -OutputPath "./.env" -IncludeSecrets
#>
function Update-DotEnvFile {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$OutputPath = "./.env",

        [Parameter()]
        [switch]$IncludeSecrets
    )

    Write-SectionHeader "Updating .env File"

    $requiredEnvVars = @(
        "REPO_PATH",
        "FORK_AUTOGEN_OWNER",
        "FORK_AUTOGEN_SSH_REPO_URL"
    )

    $secretEnvVars = @(
        "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN",
        "FORK_USER_DOCKER_ACCESS_TOKEN",
        "FORK_HUGGINGFACE_ACCESS_TOKEN"
    )

    $envContent = @"
# AutoGen environment variables
# WARNING: Do not commit tokens or secrets to version control!
# Last updated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Repository configuration
"@

    foreach ($var in $requiredEnvVars) {
        $value = [Environment]::GetEnvironmentVariable($var, "Process")
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $envContent += "`n$var=$value"
        } else {
            $envContent += "`n$var="
        }
    }

    if ($IncludeSecrets) {
        $envContent += "`n`n# Security tokens - DO NOT FILL THESE IN DIRECTLY!"
        $envContent += "`n# Use environment variables or a secure secret manager instead."

        foreach ($var in $secretEnvVars) {
            $envContent += "`n# $var="
        }
    }

    $envContent += "`n"

    $fullPath = Resolve-Path -Path $OutputPath -ErrorAction SilentlyContinue
    if (-not $fullPath) {
        $fullPath = Join-Path -Path (Get-Location) -ChildPath $OutputPath
    }

    # Back up existing file if it exists
    if (Test-Path -Path $fullPath) {
        Backup-File -FilePath $fullPath
    }

    Set-Content -Path $fullPath -Value $envContent -Encoding UTF8
    Write-StatusMessage ".env file updated at $fullPath" "Success" 2
}

<#
.SYNOPSIS
    Validates the integrity of the project environment.
.DESCRIPTION
    Performs a comprehensive check of the project environment setup.
.PARAMETER WorkspacePath
    The path to the project workspace.
.EXAMPLE
    Test-ProjectEnvironment -WorkspacePath "C:\Projects\autogen"
#>
function Test-ProjectEnvironment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath
    )

    Write-SectionHeader "Project Environment Validation"

    $issues = 0

    # Validate workspace path
    if (-not (Test-Path -Path $WorkspacePath)) {
        Write-StatusMessage "Workspace path $WorkspacePath does not exist" "Error" 2
        $issues++
    } else {
        Write-StatusMessage "Workspace path exists" "Success" 2

        # Check for primary project files and folders
        $requiredItems = @(
            "python",
            "python\pyproject.toml",
            "dotnet",
            ".vscode"
        )

        foreach ($item in $requiredItems) {
            $itemPath = Join-Path -Path $WorkspacePath -ChildPath $item
            if (-not (Test-Path -Path $itemPath)) {
                Write-StatusMessage "Required item $item is missing" "Warning" 4
                $issues++
            } else {
                Write-StatusMessage "Required item $item exists" "Success" 4
            }
        }
    }

    # Check Python environment
    try {
        $pythonVersion = & python --version 2>&1
        $pythonPath = & python -c "import sys; print(sys.executable)"

        if ($pythonVersion -match "Python (\d+\.\d+\.\d+)") {
            $version = $Matches[1]
            $majorMinor = $version -split "\." | Select-Object -First 2
            $major = [int]$majorMinor[0]
            $minor = [int]$majorMinor[1]

            if ($major -ge 3 -and $minor -ge 10) {
                Write-StatusMessage "Python version $version meets requirements" "Success" 2
            } else {
                Write-StatusMessage "Python version $version is too old (requires 3.10+)" "Error" 2
                $issues++
            }
        } else {
            Write-StatusMessage "Could not determine Python version" "Error" 2
            $issues++
        }

        Write-StatusMessage "Using Python from: $pythonPath" "Info" 2

        # Check virtual environment
        $inVirtualEnv = & python -c "import sys; print('1' if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix) else '0')"
        if ($inVirtualEnv -eq "1") {
            Write-StatusMessage "Using a Python virtual environment" "Success" 2
        } else {
            Write-StatusMessage "Not using a Python virtual environment" "Warning" 2
        }
    } catch {
        Write-StatusMessage "Python is not properly installed or configured: $_" "Error" 2
        $issues++
    }

    # Check Git configuration
    try {
        $gitVersion = & git --version
        $gitUser = & git config --get user.name
        $gitEmail = & git config --get user.email

        Write-StatusMessage "$gitVersion" "Success" 2

        if ([string]::IsNullOrWhiteSpace($gitUser) -or [string]::IsNullOrWhiteSpace($gitEmail)) {
            Write-StatusMessage "Git user.name or user.email is not configured" "Warning" 2
            $issues++
        } else {
            Write-StatusMessage "Git configured for: $gitUser <$gitEmail>" "Success" 2
        }
    } catch {
        Write-StatusMessage "Git is not properly installed or configured: $_" "Error" 2
        $issues++
    }

    # Summary
    if ($issues -gt 0) {
        Write-MessageWithColor "`nFound $issues issue(s) with the project environment." $Colors.Warning
        return $false
    } else {
        Write-MessageWithColor "`nProject environment validation completed successfully." $Colors.Success
        return $true
    }
}

# Export module members
Export-ModuleMember -Function Test-EnvironmentVariables
Export-ModuleMember -Function Set-PermanentEnvironmentVariables
Export-ModuleMember -Function Update-DotEnvFile
Export-ModuleMember -Function Test-ProjectEnvironment
