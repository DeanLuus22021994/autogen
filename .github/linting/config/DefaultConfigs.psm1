# .github\linting\config\DefaultConfigs.psm1
# Configuration templates for markdown linting

using namespace System.IO
using namespace System.Management.Automation
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Provides standard configuration templates for markdown linting tools.
.DESCRIPTION
    A collection of functions that return default configurations for various
    markdown linting tools and scenarios.
#>

function Get-MarkdownLintCliConfig {
    <#
    .SYNOPSIS
        Returns a default configuration for markdownlint-cli2.
    .DESCRIPTION
        Generates a standardized markdownlint-cli2 configuration with common
        rules and settings.
    .OUTPUTS
        [PSCustomObject] Default markdownlint-cli2 configuration
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    return [PSCustomObject]@{
        '$schema' = "https://raw.githubusercontent.com/DavidAnson/markdownlint/main/schema/markdownlint-config-schema.json"
        config = @{
            default = $true
            MD013 = $false  # Line length
            MD022 = $false  # Headers should be surrounded by blank lines
            MD025 = $false  # Multiple top-level headers
            MD031 = $false  # Fenced code blocks should be surrounded by blank lines
            MD032 = $false  # Lists should be surrounded by blank lines
            MD034 = $false  # Bare URL used
            MD055 = $false  # Table pipe style
            MD056 = $false  # Table column count
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

function Get-MarkdownLintJsonConfig {
    <#
    .SYNOPSIS
        Returns a default configuration for markdownlint in JSON format.
    .DESCRIPTION
        Generates a standardized markdownlint JSON configuration for use with
        VS Code extension and other tools that support this format.
    .OUTPUTS
        [PSCustomObject] Default markdownlint JSON configuration
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    return [PSCustomObject]@{
        default = $true
        MD013 = $false
        MD022 = $false
        MD025 = $false
        MD031 = $false
        MD032 = $false
        MD034 = $false
        MD055 = $false
        MD056 = $false
        MD046 = @{
            style = "consistent"
        }
        MD048 = @{
            style = "backtick"
        }
        MD041 = $true
        MD042 = $true
        MD043 = $true
        MD044 = $true
        customRules = @{}
    }
}

function Get-MarkdownLintRcConfig {
    <#
    .SYNOPSIS
        Returns a default configuration for .markdownlintrc file.
    .DESCRIPTION
        Generates a standardized .markdownlintrc configuration for backward
        compatibility with tools that use this format.
    .OUTPUTS
        [PSCustomObject] Default .markdownlintrc configuration
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    return [PSCustomObject]@{
        default = $true
        MD013 = $false
        MD022 = $false
        MD025 = $false
        MD031 = $false
        MD032 = $false
        MD034 = $false
        MD055 = $false
        MD056 = $false
        MD041 = $true
        MD042 = $true
        MD043 = $true
        MD044 = $true
        MD046 = @{
            style = "consistent"
        }
        MD048 = @{
            style = "backtick"
        }
    }
}

function Get-MarkdownlintIgnoreConfig {
    <#
    .SYNOPSIS
        Returns a default .markdownlintignore configuration.
    .DESCRIPTION
        Generates a standardized .markdownlintignore file content with
        common patterns to exclude from linting.
    .OUTPUTS
        [string] Default .markdownlintignore content
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return @"
README.md
node_modules/
**/package.json
**/package-lock.json
SECURITY.md
CONTRIBUTING.md
CODE_OF_CONDUCT.md
SUPPORT.md
FAQ.md
"@
}

# Export functions
Export-ModuleMember -Function @(
    'Get-MarkdownLintCliConfig',
    'Get-MarkdownLintJsonConfig',
    'Get-MarkdownLintRcConfig',
    'Get-MarkdownlintIgnoreConfig'
) | ForEach-Object { Export-ModuleMember -Function $_ }