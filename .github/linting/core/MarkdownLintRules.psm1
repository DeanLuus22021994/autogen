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

function Get-MarkdownRuleExplanation {
    <#
    .SYNOPSIS
        Gets an explanation of a markdown linting rule.
    .DESCRIPTION
        Provides documentation about what a specific markdown rule checks for.
    .PARAMETER RuleName
        The name of the rule to explain (e.g., "MD013").
    .OUTPUTS
        [string] Explanation of the rule
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleName
    )

    # Rule explanations lookup table
    $ruleExplanations = @{
        'MD001' = 'Heading levels should only increment by one level at a time'
        'MD003' = 'Heading style should be consistent'
        'MD004' = 'Unordered list style should be consistent'
        'MD005' = 'Inconsistent indentation for list items at the same level'
        'MD006' = 'Consider starting bulleted lists at the beginning of the line'
        'MD007' = 'Unordered list indentation should be consistent'
        'MD009' = 'Trailing spaces should be avoided'
        'MD010' = 'Hard tabs should be avoided'
        'MD011' = 'Reversed link syntax'
        'MD012' = 'Multiple consecutive blank lines should be avoided'
        'MD013' = 'Line length should be limited'
        'MD014' = 'Dollar signs should not be used before commands without showing output'
        'MD018' = 'No space after hash on atx style heading'
        'MD019' = 'Multiple spaces after hash on atx style heading'
        'MD020' = 'No space inside hashes on closed atx style heading'
        'MD021' = 'Multiple spaces inside hashes on closed atx style heading'
        'MD022' = 'Headings should be surrounded by blank lines'
        'MD023' = 'Headings must start at the beginning of the line'
        'MD024' = 'Multiple headings with the same content'
        'MD025' = 'Multiple top-level headings in the same document'
        'MD026' = 'Trailing punctuation in heading'
        'MD027' = 'Multiple spaces after blockquote symbol'
        'MD028' = 'Blank line inside blockquote'
        'MD029' = 'Ordered list item prefix'
        'MD030' = 'Spaces after list markers'
        'MD031' = 'Fenced code blocks should be surrounded by blank lines'
        'MD032' = 'Lists should be surrounded by blank lines'
        'MD033' = 'Inline HTML should be avoided'
        'MD034' = 'Bare URL used'
        'MD035' = 'Horizontal rule style'
        'MD036' = 'Emphasis used instead of a heading'
        'MD037' = 'Spaces inside emphasis markers'
        'MD038' = 'Spaces inside code span elements'
        'MD039' = 'Spaces inside link text'
        'MD040' = 'Fenced code blocks should have a language specified'
        'MD041' = 'First line in a file should be a top-level heading'
        'MD042' = 'No empty links'
        'MD043' = 'Required heading structure'
        'MD044' = 'Proper names should have the correct capitalization'
        'MD045' = 'Images should have alternate text (alt text)'
        'MD046' = 'Code block style should be consistent'
        'MD047' = 'Files should end with a single newline character'
        'MD048' = 'Code fence style should be consistent'
        'MD049' = 'Emphasis style should be consistent'
        'MD050' = 'Strong emphasis style should be consistent'
        'MD051' = 'Link fragments should be valid'
        'MD052' = 'Reference links should use a reference that exists'
        'MD053' = 'Link and image reference definitions should be needed'
        'MD054' = 'Link and image style'
        'MD055' = 'Table pipe style'
        'MD056' = 'Table column count'
    }

    # Return rule explanation or a default message
    return $ruleExplanations[$RuleName] ?? "No explanation available for rule $RuleName"
}

# Export functions
Export-ModuleMember -Function @(
    'Get-MarkdownLintRules',
    'Test-MarkdownFile',
    'Invoke-MarkdownLintFix',
    'Get-MarkdownRuleExplanation'
)