# .github\linting\core\ConfigurationProvider.psm1
# Centralized configuration provider for markdown linting

using namespace System.IO
using namespace System.Management.Automation
using namespace System.Collections.Concurrent

<#
.SYNOPSIS
    Provides centralized access to configuration settings for markdown linting.
.DESCRIPTION
    A module that manages configuration state across the markdown linting system,
    providing cached access to settings and handling configuration changes.
#>

# Use a thread-safe dictionary to cache configuration
$script:ConfigCache = [ConcurrentDictionary[string,object]]::new()

# Default paths
$script:DefaultPaths = @{
    ConfigDir = ".github\linting\config"
    CoreDir = ".github\linting\core"
    ScriptsDir = ".github\linting\scripts"
    UtilsDir = ".github\linting\utils"
    CommandsDir = ".github\linting\commands"
    RulesDir = ".github\linting\rules"
    MainConfig = ".github\linting\config\LintingConfig.xml"
    MarkdownlintCliConfig = ".github\linting\.markdownlint-cli2.jsonc"
    MarkdownlintJson = ".github\linting\.markdownlint.json"
    MarkdownlintIgnore = ".github\linting\.markdownlintignore"
    MarkdownlintRc = ".github\linting\.markdownlintrc"
}

function Get-ConfigurationPath {
    <#
    .SYNOPSIS
        Gets the path to a configuration file or directory.
    .DESCRIPTION
        Returns the appropriate path for a configuration resource, handling
        repository root resolution and path construction.
    .PARAMETER PathKey
        The key for the path from the default paths dictionary.
    .PARAMETER RelativePath
        Optional additional path components to append.
    .OUTPUTS
        [string] The resolved path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathKey,

        [Parameter()]
        [string]$RelativePath
    )

    # Get the base path from our defaults
    if (-not $script:DefaultPaths.ContainsKey($PathKey)) {
        throw "Unknown path key: $PathKey"
    }

    $basePath = $script:DefaultPaths[$PathKey]

    # Determine repository root
    $repoRoot = Get-RepositoryRoot

    # Construct full path
    $fullPath = Join-Path -Path $repoRoot -ChildPath $basePath

    # Add relative path if provided
    if (-not [string]::IsNullOrEmpty($RelativePath)) {
        $fullPath = Join-Path -Path $fullPath -ChildPath $RelativePath
    }

    return $fullPath
}

function Get-RepositoryRoot {
    <#
    .SYNOPSIS
        Gets the root directory of the Git repository.
    .DESCRIPTION
        Determines the root directory of the Git repository using git commands
        or falls back to current directory if not in a Git repository.
    .OUTPUTS
        [string] The repository root directory.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Check the cache first
    if ($script:ConfigCache.ContainsKey('RepoRoot')) {
        return $script:ConfigCache['RepoRoot']
    }

    # Try to get repository root using git
    try {
        $repoRoot = git rev-parse --show-toplevel 2>$null

        # Cache the result if successful
        if ($repoRoot) {
            $script:ConfigCache['RepoRoot'] = $repoRoot
            return $repoRoot
        }
    }
    catch {
        # Git command failed, fall back to current directory
    }

    # Use current directory as fallback
    $currentDir = $PWD.Path
    $script:ConfigCache['RepoRoot'] = $currentDir
    return $currentDir
}

function Get-LintingConfiguration {
    <#
    .SYNOPSIS
        Gets the linting configuration.
    .DESCRIPTION
        Loads the linting configuration from the XML file or cache.
    .PARAMETER Force
        If specified, forces a reload from disk instead of using cache.
    .OUTPUTS
        [PSCustomObject] The linting configuration.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch]$Force
    )

    # Check cache unless forced reload is requested
    if (-not $Force -and $script:ConfigCache.ContainsKey('LintingConfig')) {
        return $script:ConfigCache['LintingConfig']
    }

    # Get the configuration path
    $configPath = Get-ConfigurationPath -PathKey 'MainConfig'

    # Default configuration
    $defaultConfig = [PSCustomObject]@{
        Enabled = $true
        IgnoreDuringEditing = $false
        Settings = [PSCustomObject]@{
            AutoFix = $false
            VerboseOutput = $false
            DefaultTarget = ".github/**/*.md"
        }
    }

    # Return default if file doesn't exist
    if (-not (Test-Path -Path $configPath)) {
        $script:ConfigCache['LintingConfig'] = $defaultConfig
        return $defaultConfig
    }

    try {
        # Load and parse the XML file using .NET XML reader
        $xmlDoc = [System.Xml.XmlDocument]::new()
        $xmlDoc.Load($configPath)

        # Convert to PowerShell object
        $config = [PSCustomObject]@{
            Enabled = [bool]::Parse($xmlDoc.LintingConfiguration.Enabled)
            IgnoreDuringEditing = [bool]::Parse($xmlDoc.LintingConfiguration.IgnoreDuringEditing)
            Settings = [PSCustomObject]@{
                AutoFix = [bool]::Parse($xmlDoc.LintingConfiguration.Settings.AutoFix)
                VerboseOutput = [bool]::Parse($xmlDoc.LintingConfiguration.Settings.VerboseOutput)
                DefaultTarget = $xmlDoc.LintingConfiguration.Settings.DefaultTarget
            }
        }

        # Cache the configuration
        $script:ConfigCache['LintingConfig'] = $config
        return $config
    }
    catch {
        Write-Warning "Error loading linting configuration: $_. Using defaults."
        $script:ConfigCache['LintingConfig'] = $defaultConfig
        return $defaultConfig
    }
}

function Get-MarkdownLintToolConfig {
    <#
    .SYNOPSIS
        Gets the configuration for a specific markdown linting tool.
    .DESCRIPTION
        Loads the configuration for the specified markdown linting tool.
    .PARAMETER Tool
        The tool to get configuration for (cli2, json, rc, or ignore).
    .PARAMETER Force
        If specified, forces a reload from disk instead of using cache.
    .OUTPUTS
        [object] The tool configuration (PSCustomObject for JSON, string for ignore).
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('cli2', 'json', 'rc', 'ignore')]
        [string]$Tool,

        [Parameter()]
        [switch]$Force
    )

    # Determine cache key and path key
    $cacheKey = "ToolConfig_$Tool"
    $pathKey = switch ($Tool) {
        'cli2'   { 'MarkdownlintCliConfig' }
        'json'   { 'MarkdownlintJson' }
        'rc'     { 'MarkdownlintRc' }
        'ignore' { 'MarkdownlintIgnore' }
    }

    # Check cache unless forced reload is requested
    if (-not $Force -and $script:ConfigCache.ContainsKey($cacheKey)) {
        return $script:ConfigCache[$cacheKey]
    }

    # Get the configuration path
    $configPath = Get-ConfigurationPath -PathKey $pathKey

    # Import default configs module
    $configsModule = Get-ConfigurationPath -PathKey 'ConfigDir' -RelativePath 'DefaultConfigs.psm1'
    if (Test-Path -Path $configsModule) {
        Import-Module $configsModule -Force -DisableNameChecking
    }

    # Generate default config based on tool
    $defaultConfig = switch ($Tool) {
        'cli2'   { Get-MarkdownLintCliConfig }
        'json'   { Get-MarkdownLintJsonConfig }
        'rc'     { Get-MarkdownLintRcConfig }
        'ignore' { Get-MarkdownlintIgnoreConfig }
    }

    # If file doesn't exist, return default
    if (-not (Test-Path -Path $configPath)) {
        $script:ConfigCache[$cacheKey] = $defaultConfig
        return $defaultConfig
    }

    try {
        # Load configuration based on type
        $config = if ($Tool -eq 'ignore') {
            # For ignore file, just return content as string
            Get-Content -Path $configPath -Raw
        }
        else {
            # For JSON-based configs, parse as object
            $content = Get-Content -Path $configPath -Raw

            # If JSONC, remove comments
            if ($Tool -eq 'cli2') {
                $content = $content -replace '//.*$', '' -replace '(?m)^\s*//.*$', '' -replace '/\*[\s\S]*?\*/', ''
            }

            $content | ConvertFrom-Json
        }

        # Cache the config
        $script:ConfigCache[$cacheKey] = $config
        return $config
    }
    catch {
        Write-Warning "Error loading $Tool configuration: $_. Using defaults."
        $script:ConfigCache[$cacheKey] = $defaultConfig
        return $defaultConfig
    }
}

function Clear-ConfigurationCache {
    <#
    .SYNOPSIS
        Clears the configuration cache.
    .DESCRIPTION
        Removes cached configuration data, forcing reload from disk on next access.
    .PARAMETER CacheKey
        Optional specific cache key to clear. If not specified, clears all cache.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$CacheKey
    )

    if ([string]::IsNullOrEmpty($CacheKey)) {
        # Clear all cache
        $script:ConfigCache.Clear()
        Write-Verbose "Cleared all configuration cache"
    }
    elseif ($script:ConfigCache.ContainsKey($CacheKey)) {
        # Clear specific key
        $script:ConfigCache.TryRemove($CacheKey, [ref]$null)
        Write-Verbose "Cleared configuration cache for '$CacheKey'"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-ConfigurationPath',
    'Get-RepositoryRoot',
    'Get-LintingConfiguration',
    'Get-MarkdownLintToolConfig',
    'Clear-ConfigurationCache'
)<|/code_to_edit|>