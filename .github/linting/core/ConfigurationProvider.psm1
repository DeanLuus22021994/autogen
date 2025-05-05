# .github\linting\core\ConfigurationProvider.psm1
# Configuration provider for markdown linting

using namespace System.IO
using namespace System.Management.Automation
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Provides configuration settings for markdown linting.
.DESCRIPTION
    Central configuration provider that manages settings for markdown linting
    across the repository.
#>

# Import error handling utilities
$ErrorHandlingModule = Join-Path -Path $PSScriptRoot -ChildPath '..\utils\ErrorHandling.psm1'
if (Test-Path -Path $ErrorHandlingModule) {
    Import-Module $ErrorHandlingModule -Force
}

# Configuration cache to improve performance
$script:configCache = @{}

function Get-MarkdownLintConfiguration {
    <#
    .SYNOPSIS
        Gets the markdown linting configuration.
    .DESCRIPTION
        Retrieves the configuration settings for markdown linting,
        with caching to improve performance.
    .PARAMETER ConfigPath
        Path to the configuration file. If not specified, uses the default location.
    .PARAMETER NoCache
        If set, bypasses the cache and reads from the file system.
    .OUTPUTS
        [PSCustomObject] Configuration object
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$ConfigPath,

        [Parameter()]
        [switch]$NoCache
    )

    # Use default path if not specified
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) ".markdownlint-cli2.jsonc"
    }

    # Check if file exists
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    # Check cache first if not bypassing
    if (-not $NoCache -and $script:configCache.ContainsKey($ConfigPath)) {
        return $script:configCache[$ConfigPath]
    }

    try {
        # Read and parse the configuration file
        $configJson = Get-Content -Path $ConfigPath -Raw

        # Remove comments from JSONC if needed
        if ($ConfigPath -like "*.jsonc") {
            # Remove single-line comments
            $configJson = $configJson -replace '//.*$', '' -replace '(?m)^\\s*//.*$', ''

            # Remove multi-line comments
            $configJson = $configJson -replace '/\\*[\\s\\S]*?\\*/', ''
        }

        $config = $configJson | ConvertFrom-Json

        # Cache the result for future use
        $script:configCache[$ConfigPath] = $config

        return $config
    }
    catch {
        $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "reading configuration from $ConfigPath"
        throw $errorMessage
    }
}

function Set-MarkdownLintConfiguration {
    <#
    .SYNOPSIS
        Updates the markdown linting configuration.
    .DESCRIPTION
        Saves updated configuration settings for markdown linting.
    .PARAMETER Config
        The configuration object to save.
    .PARAMETER ConfigPath
        Path where the configuration will be saved.
    .PARAMETER MergeWithExisting
        If set, merges with existing configuration instead of replacing it.
    .OUTPUTS
        [bool] True if successful, false otherwise
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter()]
        [string]$ConfigPath,

        [Parameter()]
        [switch]$MergeWithExisting
    )

    # Use default path if not specified
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) ".markdownlint-cli2.jsonc"
    }

    try {
        if ($MergeWithExisting -and (Test-Path $ConfigPath)) {
            $existingConfig = Get-MarkdownLintConfiguration -ConfigPath $ConfigPath -NoCache

            # Merge configurations
            $mergedConfig = Merge-Configurations -BaseConfig $existingConfig -OverrideConfig $Config
            $configToSave = $mergedConfig
        }
        else {
            $configToSave = $Config
        }

        # Convert to JSON and save
        $configJson = $configToSave | ConvertTo-Json -Depth 10
        $configJson | Out-File -FilePath $ConfigPath -Encoding utf8 -Force

        # Update cache
        $script:configCache[$ConfigPath] = $configToSave

        return $true
    }
    catch {
        $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "saving configuration to $ConfigPath"
        Write-Warning $errorMessage
        return $false
    }
}

function Merge-Configurations {
    <#
    .SYNOPSIS
        Merges two configuration objects.
    .DESCRIPTION
        Combines a base configuration with an override configuration,
        with the override taking precedence.
    .PARAMETER BaseConfig
        The base configuration object.
    .PARAMETER OverrideConfig
        The configuration with values that should override the base.
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

    # Create a deep copy of the base config to avoid modifying the original
    $mergedConfig = [PSCustomObject]@{}

    # Copy properties from base config
    foreach ($prop in $BaseConfig.PSObject.Properties) {
        Add-Member -InputObject $mergedConfig -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
    }

    # Apply overrides
    foreach ($prop in $OverrideConfig.PSObject.Properties) {
        if ($mergedConfig.PSObject.Properties.Name -contains $prop.Name) {
            # Property exists in base, check if it's an object that needs recursive merging
            if ($prop.Value -is [PSCustomObject] -and $mergedConfig.($prop.Name) -is [PSCustomObject]) {
                # Recursively merge nested objects
                $mergedConfig.($prop.Name) = Merge-Configurations -BaseConfig $mergedConfig.($prop.Name) -OverrideConfig $prop.Value
            }
            else {
                # Simple override
                $mergedConfig.($prop.Name) = $prop.Value
            }
        }
        else {
            # Property doesn't exist in base, add it
            Add-Member -InputObject $mergedConfig -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
        }
    }

    return $mergedConfig
}

function Get-DefaultConfigurationPath {
    <#
    .SYNOPSIS
        Gets the default path for configuration files.
    .DESCRIPTION
        Returns the standard location for configuration files based on the type.
    .PARAMETER ConfigType
        The type of configuration file to locate.
    .OUTPUTS
        [string] Path to the configuration file
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('CLI2', 'JSON', 'RC', 'Ignore')]
        [string]$ConfigType
    )

    $baseDir = Split-Path $PSScriptRoot -Parent

    $path = switch ($ConfigType) {
        'CLI2'   { Join-Path $baseDir ".markdownlint-cli2.jsonc" }
        'JSON'   { Join-Path $baseDir ".markdownlint.json" }
        'RC'     { Join-Path $baseDir ".markdownlintrc" }
        'Ignore' { Join-Path $baseDir ".markdownlintignore" }
    }

    return $path
}

function Reset-ConfigurationCache {
    <#
    .SYNOPSIS
        Clears the configuration cache.
    .DESCRIPTION
        Resets the internal cache of configuration objects,
        forcing future reads to load from disk.
    .PARAMETER Path
        Specific configuration path to clear from cache.
        If not specified, clears the entire cache.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path
    )

    if ($Path) {
        # Remove specific path from cache
        $script:configCache.Remove($Path)
    }
    else {
        # Clear entire cache
        $script:configCache = @{}
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-MarkdownLintConfiguration',
    'Set-MarkdownLintConfiguration',
    'Get-DefaultConfigurationPath',
    'Reset-ConfigurationCache'
)