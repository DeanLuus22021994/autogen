# .github\linting\core\MarkdownLintRules.psm1
# Rules processing for markdown linting

using namespace System.IO
using namespace System.Management.Automation

<#
.SYNOPSIS
    Provides functions for managing markdown linting rules.
.DESCRIPTION
    A set of functions to manage, process, and validate markdown linting rules.
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
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable

        $rules = @()
        foreach ($ruleName in $config.config.Keys) {
            if ($ruleName -ne "default") {
                $ruleValue = $config.config[$ruleName]
                $rules += @{
                    Name = $ruleName
                    Value = $ruleValue
                }
            }
        }

        return $rules
    } catch {
        $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "parsing rules from configuration"
        throw $errorMessage
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
        $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "linting markdown file"
        throw $errorMessage
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

    # Validate file paths
    $validFiles = @()
    foreach ($file in $FilePath) {
        if (Test-Path $file) {
            $validFiles += $file
        } else {
            Write-Warning "File not found: $file"
        }
    }

    if ($validFiles.Count -eq 0) {
        Write-Warning "No valid files found to process"
        return
    }

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    try {
        # Use markdownlint-cli2 to fix issues
        & npx markdownlint-cli2 --config $ConfigPath --fix $validFiles

        Write-Host "Successfully attempted to fix issues in $($validFiles.Count) file(s)" -ForegroundColor Green
    } catch {
        $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "fixing markdown issues"
        throw $errorMessage
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

    # Rule explanations lookup table - now using a thread-safe dictionary
    $ruleExplanations = [System.Collections.Concurrent.ConcurrentDictionary[string,string]]::new()

    # Populate the dictionary
    $ruleData = @(
        @{ Key = 'MD001'; Value = 'Heading levels should only increment by one level at a time' },
        @{ Key = 'MD003'; Value = 'Heading style should be consistent' },
        @{ Key = 'MD004'; Value = 'Unordered list style should be consistent' },
        @{ Key = 'MD005'; Value = 'Inconsistent indentation for list items at the same level' },
        @{ Key = 'MD006'; Value = 'Consider starting bulleted lists at the beginning of the line' },
        @{ Key = 'MD007'; Value = 'Unordered list indentation should be consistent' },
        @{ Key = 'MD009'; Value = 'Trailing spaces should be avoided' },
        @{ Key = 'MD010'; Value = 'Hard tabs should be avoided' },
        @{ Key = 'MD011'; Value = 'Reversed link syntax' },
        @{ Key = 'MD012'; Value = 'Multiple consecutive blank lines should be avoided' },
        @{ Key = 'MD013'; Value = 'Line length should be limited' },
        @{ Key = 'MD014'; Value = 'Dollar signs should not be used before commands without showing output' },
        @{ Key = 'MD018'; Value = 'No space after hash on atx style heading' },
        @{ Key = 'MD019'; Value = 'Multiple spaces after hash on atx style heading' },
        @{ Key = 'MD020'; Value = 'No space inside hashes on closed atx style heading' },
        @{ Key = 'MD021'; Value = 'Multiple spaces inside hashes on closed atx style heading' },
        @{ Key = 'MD022'; Value = 'Headings should be surrounded by blank lines' },
        @{ Key = 'MD023'; Value = 'Headings must start at the beginning of the line' },
        @{ Key = 'MD024'; Value = 'Multiple headings with the same content' },
        @{ Key = 'MD025'; Value = 'Multiple top-level headings in the same document' },
        @{ Key = 'MD026'; Value = 'Trailing punctuation in heading' },
        @{ Key = 'MD027'; Value = 'Multiple spaces after blockquote symbol' },
        @{ Key = 'MD028'; Value = 'Blank line inside blockquote' },
        @{ Key = 'MD029'; Value = 'Ordered list item prefix' },
        @{ Key = 'MD030'; Value = 'Spaces after list markers' },
        @{ Key = 'MD031'; Value = 'Fenced code blocks should be surrounded by blank lines' },
        @{ Key = 'MD032'; Value = 'Lists should be surrounded by blank lines' },
        @{ Key = 'MD033'; Value = 'Inline HTML should be avoided' },
        @{ Key = 'MD034'; Value = 'Bare URL used' },
        @{ Key = 'MD035'; Value = 'Horizontal rule style' },
        @{ Key = 'MD036'; Value = 'Emphasis used instead of a heading' },
        @{ Key = 'MD037'; Value = 'Spaces inside emphasis markers' },
        @{ Key = 'MD038'; Value = 'Spaces inside code span elements' },
        @{ Key = 'MD039'; Value = 'Spaces inside link text' },
        @{ Key = 'MD040'; Value = 'Fenced code blocks should have a language specified' },
        @{ Key = 'MD041'; Value = 'First line in a file should be a top-level heading' },
        @{ Key = 'MD042'; Value = 'No empty links' },
        @{ Key = 'MD043'; Value = 'Required heading structure' },
        @{ Key = 'MD044'; Value = 'Proper names should have the correct capitalization' },
        @{ Key = 'MD045'; Value = 'Images should have alternate text (alt text)' },
        @{ Key = 'MD046'; Value = 'Code block style should be consistent' },
        @{ Key = 'MD047'; Value = 'Files should end with a single newline character' },
        @{ Key = 'MD048'; Value = 'Code fence style should be consistent' },
        @{ Key = 'MD049'; Value = 'Emphasis style should be consistent' },
        @{ Key = 'MD050'; Value = 'Strong emphasis style should be consistent' },
        @{ Key = 'MD051'; Value = 'Link fragments should be valid' },
        @{ Key = 'MD052'; Value = 'Reference links should use a reference that exists' },
        @{ Key = 'MD053'; Value = 'Link and image reference definitions should be needed' },
        @{ Key = 'MD054'; Value = 'Link and image style' },
        @{ Key = 'MD055'; Value = 'Table pipe style' },
        @{ Key = 'MD056'; Value = 'Table column count' }
    )

    # Add each rule to the dictionary
    foreach ($rule in $ruleData) {
        $ruleExplanations.TryAdd($rule.Key, $rule.Value)
    }

    # Return rule explanation or a default message using PowerShell 7.5 null coalescing operator
    return $ruleExplanations[$RuleName] ?? "No explanation available for rule $RuleName"
}

# Export functions
Export-ModuleMember -Function @(
    'Get-MarkdownLintRules',
    'Test-MarkdownFile',
    'Invoke-MarkdownLintFix',
    'Get-MarkdownRuleExplanation'
) | ForEach-Object { Export-ModuleMember -Function $_ }