# .github/linting/run-markdown-lint.ps1
# Script to run markdown linting with optional fix parameter

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Fix,

    [Parameter(Mandatory = $false)]
    [string]$Path
)

# Get the directory of the current script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

function Test-RulesExist {
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

    $ruleFiles = Get-ChildItem -Path $RulesDirectory -Filter "*.js" -File

    if ($ruleFiles.Count -eq 0) {
        Write-Warning "No rule files found in: $RulesDirectory"

        # Create example rule file
        $exampleRulePath = Join-Path -Path $RulesDirectory -ChildPath "example-rule.js"
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

    return $true
}

function Invoke-MarkdownLinting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Fix,

        [Parameter(Mandatory = $false)]
        [string]$Path
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

    # Use the configuration file path surrounded by double quotes
    $command += " --config `"$configPath`""

    if ($VerbosePreference -eq 'Continue') {
        Write-Verbose "Executing command: $command"
    }

    try {
        # Execute the command
        Push-Location $repoRoot
        Write-Verbose "Working directory: $repoRoot"

        if ($VerbosePreference -eq 'Continue') {
            Invoke-Expression $command
        }
        else {
            # Use the -ErrorAction SilentlyContinue to avoid errors if the command fails
            Invoke-Expression $command -ErrorAction SilentlyContinue | Out-Null
        }

        $exitCode = $LASTEXITCODE
        Pop-Location

        return ($exitCode -eq 0)
    }
    catch {
        Write-Error "Error running markdownlint: $_"
        if ($null -ne (Get-Location).Path) {
            Pop-Location
        }
        return $false
    }
}

try {
    # Ensure rules directory is set up
    $rulesDir = Join-Path -Path $scriptPath -ChildPath "rules"
    Write-Verbose "Checking rules directory: $rulesDir"
    Test-RulesExist -RulesDirectory $rulesDir

    # Run markdown linting
    if ($Fix) {
        Write-Host "Running markdown linting with auto-fix..." -ForegroundColor Cyan
        $success = Invoke-MarkdownLinting -Fix -Path $Path
    }
    else {
        Write-Host "Running markdown linting..." -ForegroundColor Cyan
        $success = Invoke-MarkdownLinting -Path $Path
    }

    if ($success) {
        Write-Host "Markdown linting completed successfully!" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Warning "Markdown linting completed with issues."
        exit 1
    }
}
catch {
    Write-Error "Error running markdown linting: $_"
    exit 1
}
