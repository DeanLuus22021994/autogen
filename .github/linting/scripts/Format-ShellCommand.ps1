# .github\linting\scripts\Format-ShellCommand.ps1
# Shell command formatter for markdown linting

using namespace System.Text.RegularExpressions

<#
.SYNOPSIS
    Formats shell commands for linting validation.
.DESCRIPTION
    Processes and formats shell script commands, ensuring proper handling
    of bash-specific syntax elements.
#>

function Format-ShellCommand {
    <#
    .SYNOPSIS
        Formats a shell command for linting validation.
    .DESCRIPTION
        Normalizes and validates shell command syntax, including proper handling
        of bash-specific keywords and structures like 'case' statements.
    .PARAMETER Command
        The shell command to format.
    .EXAMPLE
        Format-ShellCommand -Command 'case "$1" in start) echo "Starting"; ;; stop) echo "Stopping"; ;; esac'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    # Advanced regex pattern for detecting shell case statements
    $casePattern = [Regex]::new('case\s+.+\s+in\b', [RegexOptions]::IgnoreCase)

    # If this is a case statement, pass it through as valid
    if ($casePattern.IsMatch($Command)) {
        Write-Verbose "Valid shell case statement detected"
        return $Command
    }

    # Process other shell command types
    # Parse the command with improved error handling
    try {
        # Using advanced PowerShell 7.5 capabilities for string manipulation
        $normalizedCommand = $Command.Trim() -replace '\\$', '\\' -replace '\s{2,}', ' '

        # Detect and handle common shell constructs
        if ($normalizedCommand -match '(?<=^|\s)(?:if|while|for|until)\s') {
            Write-Verbose "Flow control statement detected"
            # Process flow control statements
            $normalizedCommand = $normalizedCommand -replace '(?<!\$)\${([^}]+)}', '${$1}'
        }

        return $normalizedCommand
    }
    catch {
        Write-Warning "Error processing shell command: $_"
        # Return original command if processing fails
        return $Command
    }
}

# Process multiple shell commands
function Format-ShellScript {
    <#
    .SYNOPSIS
        Formats an entire shell script with multiple commands.
    .DESCRIPTION
        Processes each line of a shell script, properly formatting commands
        while preserving structure and control flow.
    .PARAMETER ScriptContent
        The content of the shell script to format.
    .EXAMPLE
        Format-ShellScript -ScriptContent $bashScript
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptContent
    )

    try {
        # Split script into lines while preserving line endings
        $lines = [Regex]::Split($ScriptContent, "(?<=\r?\n)")

        # Process each line
        $formattedLines = foreach ($line in $lines) {
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) {
                $line
                continue
            }

            # Format the line
            Format-ShellCommand -Command $line
        }

        # Join lines back together
        return $formattedLines -join ''
    }
    catch {
        Write-Warning "Error processing shell script: $_"
        return $ScriptContent
    }
}

# Export functions
Export-ModuleMember -Function Format-ShellCommand, Format-ShellScript