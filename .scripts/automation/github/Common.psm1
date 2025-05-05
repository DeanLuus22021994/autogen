# Common.psm1
# Common utilities and shared functions for AutoGen scripts

#Requires -Version 7.0

# Export color constants for consistent styling
$script:Colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Emphasis = "Magenta"
    Muted = "DarkGray"
}

<#
.SYNOPSIS
    Writes a colorized message to the console.
.DESCRIPTION
    A utility function that writes messages with specified colors for better readability.
.PARAMETER Message
    The message to display.
.PARAMETER Color
    The color to use for the message (from $Colors or a standard console color).
.PARAMETER NoNewline
    If specified, prevents adding a newline after the message.
.EXAMPLE
    Write-MessageWithColor "Operation successful!" $Colors.Success
#>
function Write-MessageWithColor {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [string]$Color = "White",

        [Parameter()]
        [switch]$NoNewline
    )

    Write-Host $Message -ForegroundColor $Color -NoNewline:$NoNewline
}

<#
.SYNOPSIS
    Displays a formatted section header.
.DESCRIPTION
    Creates a visually distinct section header to organize console output.
.PARAMETER Title
    The title of the section.
.EXAMPLE
    Write-SectionHeader "Environment Validation"
#>
function Write-SectionHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    $width = [Math]::Min(100, $Host.UI.RawUI.WindowSize.Width - 1)
    $padding = [Math]::Max(0, ($width - $Title.Length - 4) / 2)
    $line = "=" * $width

    Write-Host ""
    Write-Host $line -ForegroundColor $Colors.Emphasis
    Write-Host ("=" * [Math]::Floor($padding)) -ForegroundColor $Colors.Emphasis -NoNewline
    Write-Host " $Title " -ForegroundColor "White" -NoNewline
    Write-Host ("=" * [Math]::Ceiling($padding)) -ForegroundColor $Colors.Emphasis
    Write-Host $line -ForegroundColor $Colors.Emphasis
    Write-Host ""
}

<#
.SYNOPSIS
    Displays a status message with an icon.
.DESCRIPTION
    Shows status messages with appropriate icons and colors for success, error, etc.
.PARAMETER Message
    The message to display.
.PARAMETER Status
    The status type ("Success", "Error", "Warning", "Info").
.PARAMETER Indent
    The number of spaces to indent the message.
.EXAMPLE
    Write-StatusMessage "Environment variables validated" "Success" 2
#>
function Write-StatusMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Success", "Error", "Warning", "Info", "Pending")]
        [string]$Status,

        [Parameter()]
        [int]$Indent = 0
    )

    $indentStr = " " * $Indent
    $icon = switch ($Status) {
        "Success" { "✓" }
        "Error"   { "✗" }
        "Warning" { "⚠" }
        "Info"    { "ℹ" }
        "Pending" { "…" }
    }

    $color = $Colors[$Status]
    Write-Host "$indentStr$icon " -ForegroundColor $color -NoNewline
    Write-Host $Message
}

<#
.SYNOPSIS
    Confirms an action with the user.
.DESCRIPTION
    Prompts the user for confirmation before proceeding with an action.
.PARAMETER Prompt
    The confirmation message to display.
.PARAMETER DefaultChoice
    The default choice (Yes/No) if the user just presses Enter.
.EXAMPLE
    if (Get-UserConfirmation "Do you want to continue?") { ... }
#>
function Get-UserConfirmation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter()]
        [ValidateSet("Yes", "No")]
        [string]$DefaultChoice = "No"
    )

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList "&Yes", "Proceeds with the operation."))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList "&No", "Cancels the operation."))

    $defaultChoiceIndex = if ($DefaultChoice -eq "Yes") { 0 } else { 1 }

    $decision = $Host.UI.PromptForChoice("Confirmation Required", $Prompt, $choices, $defaultChoiceIndex)

    return $decision -eq 0
}

<#
.SYNOPSIS
    Checks if running with administrative privileges.
.DESCRIPTION
    Determines if the current PowerShell session is running with administrative privileges.
.EXAMPLE
    if (Test-AdminPrivileges) { ... }
#>
function Test-AdminPrivileges {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
.SYNOPSIS
    Logs script operation messages to a file.
.DESCRIPTION
    Records script operations in a log file for later review.
.PARAMETER Message
    The message to log.
.PARAMETER Level
    The log level (e.g., INFO, WARNING, ERROR).
.PARAMETER LogFile
    The path to the log file.
.EXAMPLE
    Write-LogMessage "Starting environment validation" "INFO"
#>
function Write-LogMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter()]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",

        [Parameter()]
        [string]$LogFile = "$env:TEMP\autogen-scripts.log"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Create log directory if it doesn't exist
    $logDir = Split-Path -Path $LogFile -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    Add-Content -Path $LogFile -Value $logEntry

    # Also write to console based on level
    switch ($Level) {
        "ERROR"   { Write-MessageWithColor "ERROR: $Message" $Colors.Error }
        "WARNING" { Write-MessageWithColor "WARNING: $Message" $Colors.Warning }
        "DEBUG"   { if ($VerbosePreference -eq 'Continue') { Write-MessageWithColor "DEBUG: $Message" $Colors.Muted } }
        default   { if ($VerbosePreference -eq 'Continue') { Write-MessageWithColor "INFO: $Message" $Colors.Info } }
    }
}

<#
.SYNOPSIS
    Creates a backup of a file before making changes.
.DESCRIPTION
    Safely backs up a file before modifying it, with timestamped backups.
.PARAMETER FilePath
    The path to the file to back up.
.EXAMPLE
    Backup-File "C:\path\to\config.json"
#>
function Backup-File {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (Test-Path -Path $FilePath) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupDir = Join-Path -Path (Split-Path -Path $FilePath -Parent) -ChildPath "backups"

        # Create backup directory if it doesn't exist
        if (-not (Test-Path -Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        }

        $fileName = Split-Path -Path $FilePath -Leaf
        $backupPath = Join-Path -Path $backupDir -ChildPath "${fileName}.${timestamp}.bak"

        Copy-Item -Path $FilePath -Destination $backupPath -Force
        Write-LogMessage "Created backup of $FilePath at $backupPath" "INFO"

        return $backupPath
    } else {
        Write-LogMessage "Cannot back up $FilePath - file not found" "WARNING"
        return $null
    }
}

# Export module members
Export-ModuleMember -Variable Colors
Export-ModuleMember -Function Write-MessageWithColor
Export-ModuleMember -Function Write-SectionHeader
Export-ModuleMember -Function Write-StatusMessage
Export-ModuleMember -Function Get-UserConfirmation
Export-ModuleMember -Function Test-AdminPrivileges
Export-ModuleMember -Function Write-LogMessage
Export-ModuleMember -Function Backup-File
