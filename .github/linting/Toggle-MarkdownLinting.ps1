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

try {
    if (-not (Test-Path $loaderPath)) {
        throw "Linting loader module not found at $loaderPath"
    }

    . $loaderPath

    # Get current configuration
    $currentConfig = Get-LintingConfiguration

    # Determine the new enabled state using PowerShell 7 switch expression with enhanced fallthrough handling
    $newEnabled = switch -Exact ($PSCmdlet.ParameterSetName) {
        'Enable'  { $true }
        'Disable' { $false }
        'Toggle'  { -not $currentConfig.Enabled }
        default   {
            Write-Warning "Unexpected parameter set: $($PSCmdlet.ParameterSetName)"
            -not $currentConfig.Enabled
        }
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

    # Use command success pipeline instead of if/else for cleaner flow control
    $result ? {
        # Use string interpolation for cleaner string formatting
        $status = $newEnabled ? "enabled" : "disabled"
        Write-Host "Markdown linting is now $status" -ForegroundColor Green

        # Check if linting is both enabled and set to be ignored during editing
        if ($newEnabled -and ($params.IgnoreDuringEditing ?? $currentConfig.IgnoreDuringEditing)) {
            Write-Host "Note: Linting will be ignored during editing" -ForegroundColor Yellow
        }
    } : {
        # Enhanced error handling with more specific feedback
        Write-Host "Failed to update linting configuration" -ForegroundColor Red
        Write-Host "Please check if you have permission to modify the configuration file" -ForegroundColor Red
    }
}
catch {
    # Advanced error handling with PowerShell 7.5 error variable enhancements
    $errorDetails = @{
        Message = $_.Exception.Message
        Category = $_.CategoryInfo.Category
        File = $loaderPath
        LineNumber = $_.InvocationInfo.ScriptLineNumber
    }

    Write-Host "Error: $($errorDetails.Message)" -ForegroundColor Red
    Write-Verbose "Error details: $(ConvertTo-Json $errorDetails -Compress)"
    exit 1
}