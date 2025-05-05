# .github\linting\core\MarkdownLintConfig.psm1
# Configuration management for markdown linting

using namespace System.IO
using namespace System.Management.Automation

<#
.SYNOPSIS
    Provides configuration management for markdown linting.
.DESCRIPTION
    Functions to generate, validate and manage markdown linting configurations.
#>

# Import error handling utilities
$ErrorHandlingModule = Join-Path -Path $PSScriptRoot -ChildPath '..\utils\ErrorHandling.psm1'
if (Test-Path -Path $ErrorHandlingModule) {
    Import-Module $ErrorHandlingModule -Force
}

# Import file operations module
$FileOpsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\utils\FileOperations.psm1'
if (Test-Path -Path $FileOpsModule) {
    Import-Module $FileOpsModule -Force
}

function Get-DefaultMarkdownLintConfig {
    <#
    .SYNOPSIS
        Returns a default markdown linting configuration.
    .DESCRIPTION
        Generates a standard configuration object for markdown linting.
    .OUTPUTS
        [PSCustomObject] Default markdown linting configuration
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Import configuration templates if available
    $configTemplatesPath = Join-Path (Split-Path $PSScriptRoot) "config\DefaultConfigs.psm1"
    if (Test-Path $configTemplatesPath) {
        Import-Module $configTemplatesPath -Force
        return Get-MarkdownLintCliConfig
    }

    # Fallback default configuration
    return [PSCustomObject]@{
        '$schema' = "https://raw.githubusercontent.com/DavidAnson/markdownlint/main/schema/markdownlint-config-schema.json"
        config = @{
            default = $true
            MD013 = $false
            MD022 = $false
            MD025 = $false
            MD031 = $false
            MD032 = $false
            MD034 = $false
            MD055 = $false
            MD056 = $false
        }
        ignores = @(
            "README.md",
            "node_modules/**",
            "**/package.json",
            "**/package-lock.json"
        )
        customRules = @(
            ".github/linting/rules/**/*.js"
        )
        outputFormatters = @(
            @("markdownlint-cli2-formatter-default")
        )
        noProgress = $true
        fix = $false
        gitignore = $true
    }
}

function Test-MarkdownLintConfig {
    <#
    .SYNOPSIS
        Tests a markdown linting configuration for validity.
    .DESCRIPTION
        Validates that a markdown linting configuration has the required
        structure and properties.
    .PARAMETER Config
        The configuration object to validate.
    .OUTPUTS
        [bool] True if valid, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    # Basic validation
    if (-not $Config.config) {
        Write-Warning "Configuration missing 'config' property"
        return $false
    }

    # Check for required properties
    $requiredProps = @('config', 'ignores')
    foreach ($prop in $requiredProps) {
        if (-not $Config.PSObject.Properties.Name.Contains($prop)) {
            Write-Warning "Configuration missing required property: $prop"
            return $false
        }
    }

    return $true
}

function Merge-MarkdownLintConfig {
    <#
    .SYNOPSIS
        Merges two markdown linting configurations.
    .DESCRIPTION
        Combines a base configuration with overrides from a second configuration.
    .PARAMETER BaseConfig
        The base configuration object.
    .PARAMETER OverrideConfig
        The configuration with overrides to apply.
    .OUTPUTS
        [PSCustomObject] Merged configuration
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$BaseConfig,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$OverrideConfig
    )

    # Using the ?? operator from PowerShell 7.0+ for null coalescence
    $merged = [PSCustomObject]@{}

    # Copy all properties from base config
    foreach ($prop in $BaseConfig.PSObject.Properties) {
        $merged | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
    }

    # Apply overrides using PowerShell 7.5+ features for better collection handling
    foreach ($prop in $OverrideConfig.PSObject.Properties) {
        if ($merged.PSObject.Properties.Name.Contains($prop.Name)) {
            # Property exists, merge if object, otherwise replace
            if ($prop.Value -is [PSCustomObject] -and $merged.($prop.Name) -is [PSCustomObject]) {
                $merged.($prop.Name) = Merge-MarkdownLintConfig -BaseConfig $merged.($prop.Name) -OverrideConfig $prop.Value
            } else {
                $merged.($prop.Name) = $prop.Value
            }
        } else {
            # Property doesn't exist, add it
            $merged | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
        }
    }

    return $merged
}

function Export-MarkdownLintConfig {
    <#
    .SYNOPSIS
        Exports a markdown linting configuration to a file.
    .DESCRIPTION
        Saves a configuration object to a JSON or JSONC file.
    .PARAMETER Config
        The configuration object to export.
    .PARAMETER Path
        The file path where the configuration will be saved.
    .PARAMETER AsJsonc
        If true, exports as JSONC (with comments); otherwise as regular JSON.
    .OUTPUTS
        [bool] True if successful, false otherwise
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [switch]$AsJsonc
    )

    # Validate config before exporting
    if (-not (Test-MarkdownLintConfig -Config $Config)) {
        throw "Invalid markdown lint configuration"
    }

    try {
        # Use enhanced JSON conversion and error handling in PowerShell 7.5+
        $json = $Config | ConvertTo-Json -Depth 10

        # If JSONC, we could add comments here
        if ($AsJsonc) {
            # In a full implementation, we would add comments to the JSON
            # For now, we just ensure the file has the correct extension
            $Path = if ($Path -notmatch '\.jsonc$') { $Path -replace '\.json$', '.jsonc' } else { $Path }
        }

        # Save the file
        $json | Out-File -FilePath $Path -Encoding utf8 -Force
        Write-Verbose "Configuration exported to $Path"
        return $true
    }
    catch {
        $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "exporting configuration"
        throw $errorMessage
    }
}

function Import-MarkdownLintConfig {
    <#
    .SYNOPSIS
        Imports a markdown linting configuration from a file.
    .DESCRIPTION
        Loads a configuration object from a JSON or JSONC file.
    .PARAMETER Path
        The file path to load the configuration from.
    .OUTPUTS
        [PSCustomObject] Loaded configuration
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Configuration file not found: $Path"
    }

    try {
        # Read the file content
        $content = Get-Content -Path $Path -Raw

        # Remove comments if JSONC
        if ($Path -match '\.jsonc$') {
            # Remove single-line comments
            $content = $content -replace '//.*$', '' -replace '(?m)^\s*//.*$', ''

            # Remove multi-line comments
            $content = $content -replace '/\*[\s\S]*?\*/', ''
        }

        # Convert to object with enhanced error handling in PowerShell 7.5+
        $config = $content | ConvertFrom-Json -AsHashtable

        # Convert hashtable to PSCustomObject
        $configObject = [PSCustomObject]@{}
        foreach ($key in $config.Keys) {
            $value = $config[$key]

            # Recursively convert nested hashtables to PSCustomObject
            if ($value -is [Hashtable]) {
                $value = ConvertTo-PSCustomObject -Hashtable $value
            } elseif ($value -is [Array]) {
                $value = ConvertTo-PSCustomObjectArray -Array $value
            }

            $configObject | Add-Member -MemberType NoteProperty -Name $key -Value $value
        }

        # Validate the configuration
        if (-not (Test-MarkdownLintConfig -Config $configObject)) {
            Write-Warning "Imported configuration is not valid. Some features may not work correctly."
        }

        return $configObject
    }
    catch {
        $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "importing configuration"
        throw $errorMessage
    }
}

function ConvertTo-PSCustomObject {
    <#
    .SYNOPSIS
        Converts a hashtable to a PSCustomObject.
    .DESCRIPTION
        Recursively converts hashtables to PSCustomObjects for better property access.
    .PARAMETER Hashtable
        The hashtable to convert.
    .OUTPUTS
        [PSCustomObject] Converted object
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Hashtable
    )

    $customObject = [PSCustomObject]@{}

    foreach ($key in $Hashtable.Keys) {
        $value = $Hashtable[$key]

        # Recursively convert nested hashtables
        if ($value -is [hashtable]) {
            $value = ConvertTo-PSCustomObject -Hashtable $value
        } elseif ($value -is [array]) {
            $value = ConvertTo-PSCustomObjectArray -Array $value
        }

        $customObject | Add-Member -MemberType NoteProperty -Name $key -Value $value
    }

    return $customObject
}

function ConvertTo-PSCustomObjectArray {
    <#
    .SYNOPSIS
        Converts an array of hashtables to an array of PSCustomObjects.
    .DESCRIPTION
        Recursively processes array elements, converting hashtables to PSCustomObjects.
    .PARAMETER Array
        The array to process.
    .OUTPUTS
        [array] Processed array
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Array
    )

    $result = @()

    foreach ($item in $Array) {
        if ($item -is [hashtable]) {
            $result += ConvertTo-PSCustomObject -Hashtable $item
        } elseif ($item -is [array]) {
            $result += ConvertTo-PSCustomObjectArray -Array $item
        } else {
            $result += $item
        }
    }

    return $result
}

# Export functions
Export-ModuleMember -Function @(
    'Get-DefaultMarkdownLintConfig',
    'Test-MarkdownLintConfig',
    'Merge-MarkdownLintConfig',
    'Export-MarkdownLintConfig',
    'Import-MarkdownLintConfig'
) | ForEach-Object { Export-ModuleMember -Function $_ }