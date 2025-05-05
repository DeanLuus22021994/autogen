# .github/linting/Toggle-MarkdownLinting.ps1
# Script to quickly toggle markdown linting on/off

using namespace System.Management.Automation

<#
.SYNOPSIS
    Toggles markdown linting on or off.
.DESCRIPTION
    Provides a simple interface to enable or disable markdown linting
    by updating the XML configuration file.
.PARAMETER Enable
    Enables linting if specified. Cannot be used with -Disable.
.PARAMETER Disable
    Disables linting if specified. Cannot be used with -Enable.
.PARAMETER IgnoreDuringEditing
    Sets whether linting should be ignored during editing.
.EXAMPLE
    .\Toggle-MarkdownLinting.ps1 -Disable
    Turns off markdown linting.
.EXAMPLE
    .\Toggle-MarkdownLinting.ps1 -Enable -IgnoreDuringEditing $true
    Turns on markdown linting but ignores it during editing.
#>
[CmdletBinding(DefaultParameterSetName = 'Toggle')]
param(
    [Parameter(ParameterSetName = 'Enable')]
    [switch]$Enable,

    [Parameter(ParameterSetName = 'Disable')]
    [switch]$Disable,

    [Parameter()]
    [bool]$IgnoreDuringEditing = $null
)

# Import the linting loader module
$loaderPath = Join-Path $PSScriptRoot "core\LintingLoader.ps1"

if (-not (Test-Path $loaderPath)) {
    Write-Host "Error: Linting loader module not found at $loaderPath" -ForegroundColor Red
    exit 1
}

. $loaderPath

# Get current configuration
$currentConfig = Get-LintingConfiguration

# Determine the new enabled state using PowerShell 7 switch expression
$newEnabled = switch ($PSCmdlet.ParameterSetName) {
    'Enable'  { $true }
    'Disable' { $false }
    'Toggle'  { -not $currentConfig.Enabled }
}

# Update the configuration using splatting for cleaner parameter passing
$params = @{
    Enabled = $newEnabled
}

# Add IgnoreDuringEditing if specified using null-conditional operator
if ($null -ne $IgnoreDuringEditing) {
    $params.IgnoreDuringEditing = $IgnoreDuringEditing
}

# Update configuration and handle result
$result = Update-LintingConfiguration @params

if ($result) {
    # Use string interpolation for cleaner string formatting
    $status = if ($newEnabled) { "enabled" } else { "disabled" }
    Write-Host "Markdown linting is now $status" -ForegroundColor Green

    # Use PowerShell 7 null-coalescing operator for more concise code
    if ($newEnabled -and ($params.IgnoreDuringEditing ?? $currentConfig.IgnoreDuringEditing)) {
        Write-Host "Note: Linting will be ignored during editing" -ForegroundColor Yellow
    }
}
else {
    Write-Host "Failed to update linting configuration" -ForegroundColor Red
}