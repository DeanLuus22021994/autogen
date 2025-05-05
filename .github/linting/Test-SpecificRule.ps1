# Test-SpecificRule.ps1
# Script to test a specific markdown rule against example files

<#
.SYNOPSIS
    Tests a specific markdown linting rule against example files.

.DESCRIPTION
    This script runs a specific markdown linting rule against example markdown files
    to verify its behavior. It's useful for rule development and validation.

.PARAMETER RuleName
    The name of the rule to test (without .js extension).

.PARAMETER ExampleDir
    The directory containing example markdown files.
    Defaults to .github/linting/examples.

.PARAMETER UseDocker
    If specified, runs the test in Docker. Otherwise, runs locally.

.PARAMETER Verbose
    If specified, shows detailed output from the testing process.

.EXAMPLE
    .\Test-SpecificRule.ps1 -RuleName sample-rule
    Tests the sample-rule against example files using local Node.js.

.EXAMPLE
    .\Test-SpecificRule.ps1 -RuleName http-urls -UseDocker -Verbose
    Tests the http-urls rule in Docker with verbose output.
#>

.EXAMPLE
    .\Test-SpecificRule.ps1 -RuleName "custom-rule-sample"
    Tests the custom-rule-sample against example files.

.EXAMPLE
    .\Test-SpecificRule.ps1 -RuleName "no-http-urls" -ExampleDir "docs/examples" -UseDocker
    Tests the no-http-urls rule against example files in docs/examples using Docker.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RuleName,

    [Parameter(Mandatory = $false)]
    [string]$ExampleDir,

    [Parameter(Mandatory = $false)]
    [switch]$UseDocker
)

# Get the directory of the current script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Set default values if not specified
if (-not $ExampleDir) {
    $ExampleDir = Join-Path -Path $scriptPath -ChildPath "examples"
}

# Create examples directory if it doesn't exist
if (-not (Test-Path -Path $ExampleDir)) {
    New-Item -Path $ExampleDir -ItemType Directory -Force | Out-Null
    Write-Host "Created examples directory: $ExampleDir" -ForegroundColor Yellow
}

# Path to rule file
$ruleFile = Join-Path -Path $scriptPath -ChildPath "rules\$RuleName.js"

# Check if rule file exists
if (-not (Test-Path -Path $ruleFile)) {
    Write-Error "Rule file not found: $ruleFile"
    exit 1
}

# Create a temporary directory for rule testing
$tempRuleDir = Join-Path -Path $env:TEMP -ChildPath "markdown-rule-test-$RuleName"
if (Test-Path -Path $tempRuleDir) {
    Remove-Item -Path $tempRuleDir -Recurse -Force
}
New-Item -Path $tempRuleDir -ItemType Directory -Force | Out-Null

# Copy the rule to the temp directory
Copy-Item -Path $ruleFile -Destination $tempRuleDir

# Create a minimal config file for testing just this rule
$configContent = @"
{
  "config": {
    "default": false
  },
  "customRules": ["$($RuleName).js"]
}
"@
$configFile = Join-Path -Path $tempRuleDir -ChildPath ".markdownlint-cli2.json"
$configContent | Out-File -FilePath $configFile -Encoding utf8

# Run the test
$testArgs = @{
    Path = $ExampleDir
    RulesDirectory = $tempRuleDir
    ConfigFile = $configFile
    Detailed = $true
}

if ($UseDocker) {
    $testArgs.Add("BuildContainer", $true)
} else {
    $testArgs.Add("Local", $true)
}

Write-Host "🧪 Testing rule: $RuleName" -ForegroundColor Cyan
Write-Host "📂 Examples directory: $ExampleDir" -ForegroundColor Cyan
Write-Host "🔍 Testing mode: $(if ($UseDocker) { "Docker" } else { "Local" })" -ForegroundColor Cyan

# Call the main testing script
$testScript = Join-Path -Path $scriptPath -ChildPath "Test-MarkdownRules.ps1"
& $testScript @testArgs

# Clean up
Remove-Item -Path $tempRuleDir -Recurse -Force

exit $LASTEXITCODE
