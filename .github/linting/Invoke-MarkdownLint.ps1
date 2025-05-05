# .github/linting/Invoke-MarkdownLint.ps1
# Advanced script to run markdown linting with more options

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Fix,

    [Parameter(Mandatory = $false)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [switch]$ShowResults,

    [Parameter(Mandatory = $false)]
    [switch]$IgnoreErrors
)

# Get the directory of the current script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Import any available helper modules
$helperModulePath = Join-Path -Path $scriptPath -ChildPath "MarkdownLintHelpers.psm1"
if (Test-Path -Path $helperModulePath) {
    Import-Module -Name $helperModulePath -Force
    Write-Verbose "Imported helper module: $helperModulePath"
}

function Test-RulesDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RulesDirectory
    )

    if (-not (Test-Path -Path $RulesDirectory)) {
        Write-Warning "Rules directory not found: $RulesDirectory"
        New-Item -Path $RulesDirectory -ItemType Directory -Force | Out-Null
        Write-Host "Created rules directory: $RulesDirectory" -ForegroundColor Green
    }

    # Ensure there's at least one rule file
    $ruleFiles = Get-ChildItem -Path $RulesDirectory -Filter "*.js" -File -ErrorAction SilentlyContinue

    if ($null -eq $ruleFiles -or $ruleFiles.Count -eq 0) {
        Write-Warning "No rule files found in: $RulesDirectory"

        # Create example rule file if it doesn't exist
        $exampleRulePath = Join-Path -Path $RulesDirectory -ChildPath "example-rule.js"
        if (-not (Test-Path -Path $exampleRulePath)) {
            $exampleRuleContent = @'
// Basic example rule to ensure the rules directory has valid content

"use strict";

module.exports = {
  names: ["example-rule"],
  description: "Example custom rule",
  tags: ["autogen", "example"],
  function: function rule(params, onError) {
    params.tokens.filter(function filterToken(token) {
      return token.type === "heading_open";
    }).forEach(function forToken(token) {
      if (token.line.trim().length > 80) {
        onError({
          lineNumber: token.lineNumber,
          detail: "Heading line is too long",
          context: token.line.trim()
        });
      }
    });
  }
};
'@
            Set-Content -Path $exampleRulePath -Value $exampleRuleContent -Force
            Write-Host "Created example rule: $exampleRulePath" -ForegroundColor Green
        }
    }
}

function Invoke-MarkdownLintingTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Fix,

        [Parameter(Mandatory = $false)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [switch]$ShowResults,

        [Parameter(Mandatory = $false)]
        [switch]$IgnoreErrors
    )

    $configPath = Join-Path -Path $scriptPath -ChildPath ".markdownlint-cli2.jsonc"

    if (-not (Test-Path -Path $configPath)) {
        Write-Error "Configuration file not found: $configPath"
        return $false
    }

    # Build the command
    $command = "npx markdownlint-cli2"

    if ($Fix) {
        $command += " --fix"
    }

    if ($Path) {
        $command += " `"$Path`""
    }
    else {
        $command += " `"**/*.md`""
    }

    # Add config path
    $command += " --config `"$configPath`""

    Write-Verbose "Executing command: $command"

    try {
        # Execute the command
        Push-Location $repoRoot
        Write-Verbose "Working directory: $repoRoot"

        $output = $null
        if ($ShowResults) {
            # If ShowResults is true, display the output directly to the console
            Invoke-Expression $command
        }
        else {
            # Otherwise, capture the output for processing
            $output = Invoke-Expression $command 2>&1
        }

        $exitCode = $LASTEXITCODE
        Pop-Location

        # If there was an error and we're not ignoring errors, show the output
        if ($exitCode -ne 0 -and -not $IgnoreErrors -and -not $ShowResults -and $null -ne $output) {
            Write-Host "Linting output:" -ForegroundColor Yellow
            $output | ForEach-Object { Write-Host $_ }
        }

        return ($exitCode -eq 0)
    }
    catch {
        Write-Error "Error running markdownlint: $_"
        if ($null -ne (Get-Location)) {
            Pop-Location
        }
        return $false
    }
}

try {
    # Ensure rules directory is properly set up
    $rulesDir = Join-Path -Path $scriptPath -ChildPath "rules"
    Write-Verbose "Checking rules directory: $rulesDir"
    Test-RulesDirectory -RulesDirectory $rulesDir

    # Run markdown linting
    if ($Fix) {
        Write-Host "Running markdown linting with auto-fix..." -ForegroundColor Cyan
        $success = Invoke-MarkdownLintingTool -Fix -Path $Path -ShowResults:$ShowResults -IgnoreErrors:$IgnoreErrors
    }
    else {
        Write-Host "Running markdown linting..." -ForegroundColor Cyan
        $success = Invoke-MarkdownLintingTool -Path $Path -ShowResults:$ShowResults -IgnoreErrors:$IgnoreErrors
    }

    # Report results
    if ($success) {
        Write-Host "Markdown linting completed successfully!" -ForegroundColor Green
        exit 0
    }
    else {
        if ($IgnoreErrors) {
            Write-Warning "Markdown linting completed with issues (ignored)."
            exit 0
        }
        else {
            Write-Warning "Markdown linting completed with issues."
            exit 1
        }
    }
}
catch {
    Write-Error "Error running markdown linting: $_"
    exit 1
}
