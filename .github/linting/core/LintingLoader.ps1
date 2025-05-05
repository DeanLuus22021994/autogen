# .github\linting\core\LintingLoader.ps1
# Loads linting configuration and controls linting behavior

using namespace System.Xml
using namespace System.IO

<#
.SYNOPSIS
    Loads and manages linting configuration from XML.
.DESCRIPTION
    Provides functions to read the linting configuration XML file
    and determine if linting should be enabled or disabled.
#>

# Import error handling helpers
$ErrorHandlingModule = Join-Path -Path $PSScriptRoot -ChildPath '..\utils\ErrorHandling.psm1'
if (Test-Path -Path $ErrorHandlingModule) {
    Import-Module $ErrorHandlingModule -Force
}

function Get-LintingConfiguration {
    <#
    .SYNOPSIS
        Gets the current linting configuration.
    .DESCRIPTION
        Reads the XML configuration file and returns the settings.
    .OUTPUTS
        [PSCustomObject] Linting configuration object
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $configPath = Join-Path $PSScriptRoot "..\config\LintingConfig.xml"

    # Default configuration if file doesn't exist
    $defaultConfig = [PSCustomObject]@{
        Enabled = $true
        IgnoreDuringEditing = $false
        Settings = [PSCustomObject]@{
            AutoFix = $false
            VerboseOutput = $false
            DefaultTarget = ".github/**/*.md"
        }
    }

    # Return default config if file doesn't exist
    if (-not (Test-Path $configPath)) {
        Write-Verbose "Configuration file not found, using defaults"
        return $defaultConfig
    }

    try {
        # Read XML config using .NET XML reader for better performance
        $xmlDoc = [XmlDocument]::new()
        $xmlDoc.Load($configPath)

        # Convert XML to PowerShell object
        $config = [PSCustomObject]@{
            Enabled = [bool]::Parse($xmlDoc.LintingConfiguration.Enabled)
            IgnoreDuringEditing = [bool]::Parse($xmlDoc.LintingConfiguration.IgnoreDuringEditing)
            Settings = [PSCustomObject]@{
                AutoFix = [bool]::Parse($xmlDoc.LintingConfiguration.Settings.AutoFix)
                VerboseOutput = [bool]::Parse($xmlDoc.LintingConfiguration.Settings.VerboseOutput)
                DefaultTarget = $xmlDoc.LintingConfiguration.Settings.DefaultTarget
            }
        }

        return $config
    }
    catch {
        # Use Write-Warning with a formatted error message
        $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "reading linting configuration"
        Write-Warning $errorMessage
        return $defaultConfig
    }
}

function Test-LintingEnabled {
    <#
    .SYNOPSIS
        Checks if linting is currently enabled.
    .DESCRIPTION
        Determines if linting should be active based on configuration
        and current environment conditions.
    .PARAMETER IsEditingMode
        Whether the current operation is during file editing.
    .OUTPUTS
        [bool] True if linting should be enabled, False otherwise
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [switch]$IsEditingMode
    )

    $config = Get-LintingConfiguration

    # If globally disabled, return false
    if (-not $config.Enabled) {
        return $false
    }

    # If in editing mode and we should ignore during editing
    if ($IsEditingMode -and $config.IgnoreDuringEditing) {
        return $false
    }

    return $true
}

function Update-LintingConfiguration {
    <#
    .SYNOPSIS
        Updates the linting configuration.
    .DESCRIPTION
        Writes updated settings to the XML configuration file.
    .PARAMETER Enabled
        Whether linting should be enabled.
    .PARAMETER IgnoreDuringEditing
        Whether linting should be ignored during editing.
    .PARAMETER AutoFix
        Whether auto-fix should be enabled.
    .PARAMETER VerboseOutput
        Whether verbose output should be enabled.
    .PARAMETER DefaultTarget
        The default glob pattern for files to lint.
    .OUTPUTS
        [bool] True if the update succeeds, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [bool]$Enabled,

        [Parameter()]
        [bool]$IgnoreDuringEditing,

        [Parameter()]
        [bool]$AutoFix,

        [Parameter()]
        [bool]$VerboseOutput,

        [Parameter()]
        [string]$DefaultTarget
    )

    $configPath = Join-Path $PSScriptRoot "..\config\LintingConfig.xml"
    $configDir = Split-Path $configPath -Parent

    # Create directory if it doesn't exist
    if (-not (Test-Path $configDir)) {
        try {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        catch {
            $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "creating configuration directory"
            Write-Warning $errorMessage
            return $false
        }
    }

    # Get current config if it exists
    $currentConfig = Get-LintingConfiguration

    # Create XML document
    $xmlDoc = [XmlDocument]::new()

    # Create XML declaration
    $declaration = $xmlDoc.CreateXmlDeclaration("1.0", "utf-8", $null)
    $xmlDoc.AppendChild($declaration) | Out-Null

    # Create root element
    $root = $xmlDoc.CreateElement("LintingConfiguration")

    # Use the null-coalescing operator to set values
    # Create enabled element
    $enabledElement = $xmlDoc.CreateElement("Enabled")
    $enabledElement.InnerText = ($Enabled ?? $currentConfig.Enabled).ToString().ToLower()
    $root.AppendChild($enabledElement) | Out-Null

    # Create ignore during editing element
    $ignoreElement = $xmlDoc.CreateElement("IgnoreDuringEditing")
    $ignoreElement.InnerText = ($IgnoreDuringEditing ?? $currentConfig.IgnoreDuringEditing).ToString().ToLower()
    $root.AppendChild($ignoreElement) | Out-Null

    # Create settings element
    $settingsElement = $xmlDoc.CreateElement("Settings")

    # Create auto-fix element
    $autoFixElement = $xmlDoc.CreateElement("AutoFix")
    $autoFixElement.InnerText = ($AutoFix ?? $currentConfig.Settings.AutoFix).ToString().ToLower()
    $settingsElement.AppendChild($autoFixElement) | Out-Null

    # Create verbose output element
    $verboseElement = $xmlDoc.CreateElement("VerboseOutput")
    $verboseElement.InnerText = ($VerboseOutput ?? $currentConfig.Settings.VerboseOutput).ToString().ToLower()
    $settingsElement.AppendChild($verboseElement) | Out-Null

    # Create default target element
    $targetElement = $xmlDoc.CreateElement("DefaultTarget")
    $targetElement.InnerText = $DefaultTarget ?? $currentConfig.Settings.DefaultTarget
    $settingsElement.AppendChild($targetElement) | Out-Null

    # Add settings to root
    $root.AppendChild($settingsElement) | Out-Null

    # Add root to document
    $xmlDoc.AppendChild($root) | Out-Null

    # Save document
    try {
        $xmlDoc.Save($configPath)
        Write-Verbose "Linting configuration updated successfully"
        return $true
    }
    catch {
        $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "updating linting configuration"
        Write-Warning $errorMessage
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Get-LintingConfiguration, Test-LintingEnabled, Update-LintingConfiguration