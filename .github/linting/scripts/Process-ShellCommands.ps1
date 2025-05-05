# .github/linting/scripts/Process-ShellCommands.ps1
# Shell command processing utilities

<#
.SYNOPSIS
    Provides functions for processing and handling shell commands.
.DESCRIPTION
    Utilities for working with shell scripts, including bash-specific syntax.
#>

# cSpell:ignore esac
# Note: In shell scripts, "case" blocks end with "esac" (case spelled backwards)
# This is not a spelling error but a valid shell scripting construct

function Process-ShellCommand {
    <#
    .SYNOPSIS
        Process shell commands with proper handling of shell-specific syntax.
    .DESCRIPTION
        Ensures shell script syntax is properly parsed and understood,
        accounting for shell-specific keywords and structures.
    .PARAMETER Command
        The shell command to process.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    # Handle case statements
    if ($Command -match "case\s+.+\s+in") {
        # Validate case statement structure
        if (-not ($Command -match "esac")) {
            Write-Warning "Shell case statement missing closing 'esac'"
        }

        # Process case patterns
        $patterns = [regex]::Matches($Command, "\)\s*(?:\#.*)?$", [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($patterns.Count -gt 0) {
            Write-Verbose "Found $($patterns.Count) case patterns in shell command"
        }

        return $Command
    }

    # Handle other shell constructs
    if ($Command -match "\bif\s+.*;s*then\b" -or $Command -match "\bfor\s+.*;s*do\b" -or $Command -match "\bwhile\s+.*;s*do\b") {
        # Shell conditional or loop detected
        Write-Verbose "Processing shell conditional or loop"
        return $Command
    }

    # Default processing
    return $Command
}

function Get-ShellShebang {
    <#
    .SYNOPSIS
        Extracts the shebang line from a shell script.
    .DESCRIPTION
        Identifies and returns the interpreter directive (shebang) from a shell script.
    .PARAMETER ScriptPath
        Path to the shell script file.
    .OUTPUTS
        [string] The shebang line or empty string if not found.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    if (-not (Test-Path $ScriptPath)) {
        Write-Warning "Script file not found: $ScriptPath"
        return ""
    }

    $firstLine = Get-Content -Path $ScriptPath -TotalCount 1
    if ($firstLine -match "^#!") {
        return $firstLine
    }

    return ""
}

function Set-ShellScriptExecutable {
    <#
    .SYNOPSIS
        Sets the executable permission on a shell script.
    .DESCRIPTION
        Makes a shell script executable in Unix/Linux environments.
    .PARAMETER ScriptPath
        Path to the shell script file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    if (-not (Test-Path $ScriptPath)) {
        Write-Warning "Script file not found: $ScriptPath"
        return
    }

    # Check if running on Unix/Linux
    if ($IsLinux -or $IsMacOS) {
        try {
            # Set executable permission
            chmod +x $ScriptPath
            Write-Verbose "Set executable permission on $ScriptPath"
        }
        catch {
            Write-Warning "Failed to set executable permission on $ScriptPath: $_"
        }
    }
    else {
        Write-Verbose "Not running on Unix/Linux, skipping executable permission"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Process-ShellCommand',
    'Get-ShellShebang',
    'Set-ShellScriptExecutable'
)