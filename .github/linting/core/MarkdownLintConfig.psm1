# .github/linting/core/MarkdownLintConfig.psm1
# Configuration management for markdown linting

using namespace System.IO
using namespace System.Management.Automation

<#
.SYNOPSIS
    Provides configuration management for markdown linting.
.DESCRIPTION
    Functions to generate, validate and manage markdown linting configurations.
#>

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

    return [PSCustomObject]@{
        '$schema' = "https://raw.githubusercontent.com/DavidAnson/markdownlint/main/schema/markdownlint-config-schema.json"
        config = @{
            default = $true
            MD013 = @{ line_length = 120 }
            MD024 = @{ allow_different_nesting = $true }
            MD033 = @{ allowed_elements = @("br", "img", "a") }
            MD041 = $false
        }
        ignores = @(
            "node_modules/**",
            ".git/**",
            "**/*.svg"
        )
        customRules = @(
            ".github/linting/rules/**/*.js"
        )
        outputFormatters = @(
            @("markdownlint-cli2-formatter-pretty", @{ appendLink = $true })
        )
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

    $merged = [PSCustomObject]@{}

    # Copy all properties from base config
    foreach ($prop in $BaseConfig.PSObject.Properties) {
        $merged | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
    }

    # Apply overrides
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

# Export functions
Export-ModuleMember -Function @(
    'Get-DefaultMarkdownLintConfig',
    'Test-MarkdownLintConfig',
    'Merge-MarkdownLintConfig'
)