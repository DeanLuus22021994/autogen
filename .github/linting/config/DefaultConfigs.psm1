# .github/linting/config/DefaultConfigs.psm1
# Default configuration templates for markdown linting

<#
.SYNOPSIS
    Provides default configuration templates for markdown linting.
.DESCRIPTION
    A collection of functions that return standard configurations for
    various markdown linting tools and formats.
#>

function Get-MarkdownLintCliConfig {
    <#
    .SYNOPSIS
        Returns a default configuration for markdownlint-cli2.
    .DESCRIPTION
        Provides a standardized configuration object for the markdownlint-cli2 tool.
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
            MD013 = $false
            MD022 = $false
            MD025 = $false
            MD031 = $false
            MD032 = $false
            MD034 = $false
            MD055 = $false
            MD056 = $false
        }
        customRules = @(
            ".github/linting/rules/**/*.js"
        )
        ignores = @(
            "README.md",
            "node_modules/**",
            "**/package.json",
            "**/package-lock.json"
        )
        noProgress = $true
        outputFormatters = @(
            @("markdownlint-cli2-formatter-default")
        )
        fix = $false
        gitignore = $true
    }
}

function Get-MarkdownLintJsonConfig {
    <#
    .SYNOPSIS
        Returns a default configuration for .markdownlint.json.
    .DESCRIPTION
        Provides a standardized configuration object for .markdownlint.json.
    .OUTPUTS
        [PSCustomObject] Default .markdownlint.json configuration
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
        MD024 = @{ siblings_only = $true }
        MD046 = @{ style = "consistent" }
        MD048 = @{ style = "backtick" }
        MD041 = $true
        MD042 = $true
        MD043 = $true
        MD044 = $true
    }
}

function Get-MarkdownLintIgnoreConfig {
    <#
    .SYNOPSIS
        Returns default content for .markdownlintignore.
    .DESCRIPTION
        Provides standardized patterns for files to ignore in markdown linting.
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

function Get-MarkdownLintRcConfig {
    <#
    .SYNOPSIS
        Returns a default configuration for .markdownlintrc.
    .DESCRIPTION
        Provides a standardized configuration object for .markdownlintrc.
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
        MD046 = @{ style = "consistent" }
        MD048 = @{ style = "backtick" }
    }
}

function Get-ReadmeContent {
    <#
    .SYNOPSIS
        Returns default content for the README.md file.
    .DESCRIPTION
        Provides standardized documentation for the markdown linting configuration.
    .OUTPUTS
        [string] Default README.md content
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return @"
# Markdown Linting Tools

This directory contains tools and configurations for enforcing consistent markdown formatting across the repository.

## Overview

The markdown linting system provides:

- Standardized rules for all markdown documents
- Automated validation and fixing of common issues
- Integration with VS Code and other editors
- Custom rules specific to the project's needs

## Setup

To set up the markdown linting environment:

```powershell
# From repository root
./.github/linting/Initialize-MarkdownLinting.ps1
```