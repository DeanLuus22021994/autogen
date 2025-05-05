# .github/linting/core/MarkdownLintRules.psm1
# Rules processing for markdown linting

using namespace System.IO
using namespace System.Management.Automation

<#
.SYNOPSIS
    Provides functions for managing markdown linting rules.
.DESCRIPTION
    A set of functions to manage, process, and validate markdown linting rules.
#>

function Get-MarkdownLintRules {
    <#
    .SYNOPSIS
        Gets all defined markdown linting rules.
    .DESCRIPTION
        Retrieves the list of markdown linting rules from the configuration.
    .PARAMETER ConfigPath
        Path to the markdown linting configuration file.
    .OUTPUTS
        [hashtable[]] Array of rule definitions
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

        $rules = @()
        foreach ($ruleName in $config.config.PSObject.Properties.Name) {
            if ($ruleName -ne "default") {
                $ruleValue = $config.config.$ruleName
                $rules += @{
                    Name = $ruleName
                    Value = $ruleValue
                }
            }
        }

        return $rules
    } catch {
        throw "Error parsing rules from configuration: $_"
    }
}

function Test-MarkdownFile {
    <#
    .SYNOPSIS
        Tests a markdown file against linting rules.
    .DESCRIPTION
        Validates that a markdown file conforms to the defined rules.
    .PARAMETER FilePath
        Path to the markdown file to test.
    .PARAMETER ConfigPath
        Path to the markdown linting configuration file.
    .OUTPUTS
        [PSCustomObject[]] Linting results
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (-not (Test-Path $FilePath)) {
        throw "Markdown file not found: $FilePath"
    }

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    try {
        # Use markdownlint-cli2 to lint the file
        $results = & npx markdownlint-cli2 --config $ConfigPath $FilePath --json

        # Parse the JSON results
        $parsedResults = $results | ConvertFrom-Json

        return $parsedResults
    } catch {
        throw "Error linting markdown file: $_"
    }
}

function Invoke-MarkdownLintFix {
    <#
    .SYNOPSIS
        Attempts to automatically fix markdown linting issues.
    .DESCRIPTION
        Runs the auto-fix functionality of markdownlint on specified files.
    .PARAMETER FilePath
        Path to the markdown file(s) to fix.
    .PARAMETER ConfigPath
        Path to the markdown linting configuration file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    foreach ($file in $FilePath) {
        if (-not (Test-Path $file)) {
            Write-Warning "File not found: $file"
            continue
        }
    }

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    try {
        # Use markdownlint-cli2 to fix issues
        & npx markdownlint-cli2 --config $ConfigPath --fix $FilePath

        Write-Host "Successfully attempted to fix issues in $($FilePath.Count) file(s)" -ForegroundColor Green
    } catch {
        throw "Error fixing markdown issues: $_"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-MarkdownLintRules',
    'Test-MarkdownFile',
    'Invoke-MarkdownLintFix'
)