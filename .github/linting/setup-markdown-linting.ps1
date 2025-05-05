param(
    [switch]$Force,
    [switch]$Validate,
    [switch]$Help,
    [switch]$CleanupRoot
)

if ($Help) {
    Write-Host "Markdown Linting Setup Script"
    Write-Host "Parameters: -Force -Validate -CleanupRoot -Help"
    exit 0
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
} else {
    Write-Host "Error: Not in a git repository."
    exit 1
}

$prerequisites = @{
    "Node.js" = { Get-Command node -ErrorAction SilentlyContinue }
    "npm"     = { Get-Command npm -ErrorAction SilentlyContinue }
    "npx"     = { Get-Command npx -ErrorAction SilentlyContinue }
}
$missingPrerequisites = @()
foreach ($prerequisite in $prerequisites.Keys) {
    $check = $prerequisites[$prerequisite].Invoke()
    if (-not $check) {
        $missingPrerequisites += $prerequisite
    }
}

if ($missingPrerequisites.Count -gt 0) {
    Write-Host "Warning: Missing prerequisites:" -ForegroundColor Yellow
    foreach ($missing in $missingPrerequisites) {
        Write-Host "  - $missing" -ForegroundColor Yellow
    }
    Write-Host "Some functionality may not work properly without these tools." -ForegroundColor Yellow
    if (-not $Force) {
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne "y") {
            Write-Host "Operation canceled." -ForegroundColor Red
            exit 1
        }
    }
}

$lintingDir = ".github/linting"
if (-not (Test-Path $lintingDir)) {
    Write-Host "Creating $lintingDir directory..." -ForegroundColor Yellow
    New-Item -Path $lintingDir -ItemType Directory -Force | Out-Null
    Write-Host "Directory created successfully." -ForegroundColor Green
} else {
    Write-Host "Directory $lintingDir already exists." -ForegroundColor Green
}

# ----------------------------------------------------------------
# Configuration contents for linting files
# ----------------------------------------------------------------
$markdownlintCli2Content = @'
{
  "config": {
    "default": true,
    "MD013": false,
    "MD022": false,
    "MD025": false,
    "MD031": false,
    "MD032": false,
    "MD034": false,
    "MD055": false,
    "MD056": false
  },
  "overrides": [
    {
      "glob": ".github/**/*.md",
      "config": {
        "default": true,
        "MD013": { "line_length": 100 },
        "MD022": true,
        "MD025": true,
        "MD031": true,
        "MD032": true,
        "MD034": true,
        "MD041": true,
        "MD042": true,
        "MD043": true,
        "MD044": true,
        "MD046": { "style": "consistent" },
        "MD048": { "style": "backtick" }
      }
    }
  ],
  "ignores": [
    "README.md",
    "node_modules/**",
    "**/package.json",
    "**/package-lock.json"
  ],
  "noProgress": true,
  "outputFormatters": [
    [
      "markdownlint-cli2-formatter-default"
    ]
  ],
  "fix": false,
  "gitignore": true
}
'@

$markdownlintJsonContent = @'
{
  "default": true,
  "MD013": false,
  "MD022": false,
  "MD025": false,
  "MD031": false,
  "MD032": false,
  "MD034": false,
  "MD055": false,
  "MD056": false,
  "customRules": [],
  "MD046": { "style": "consistent" },
  "MD048": { "style": "backtick" },
  "MD041": true,
  "MD042": true,
  "MD043": true,
  "MD044": true
}
'@

$markdownlintIgnoreContent = @'
README.md
node_modules/
**/package.json
**/package-lock.json
SECURITY.md
CONTRIBUTING.md
CODE_OF_CONDUCT.md
SUPPORT.md
FAQ.md
'@

$markdownlintrcContent = @'
{
  "default": true,
  "MD013": false,
  "MD022": false,
  "MD025": false,
  "MD031": false,
  "MD032": false,
  "MD034": false,
  "MD055": false,
  "MD056": false,
  "MD041": true,
  "MD042": true,
  "MD043": true,
  "MD044": true,
  "MD046": { "style": "consistent" },
  "MD048": { "style": "backtick" }
}
'@

$syncConfigContent = @'
# Sync Markdown Linting Configuration
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
}
$configFiles = @(
    @{
        Source = ".github\linting\.markdownlint-cli2.jsonc"
        Target = ".markdownlint-cli2.jsonc"
    },
    @{
        Source = ".github\linting\.markdownlint.json"
        Target = ".markdownlint.json"
    },
    @{
        Source = ".github\linting\.markdownlintignore"
        Target = ".markdownlintignore"
    },
    @{
        Source = ".github\linting\.markdownlintrc"
        Target = ".markdownlintrc"
    }
)
function Sync-File {
    param (
        [string]$Source,
        [string]$Target
    )
    if (Test-Path $Target) {
        Remove-Item $Target -Force
    }
    try {
        if ($IsWindows -or $ENV:OS -match "Windows") {
            $adminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if ($adminRights) {
                New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
                Write-Host "Created symbolic link: $Target -> $Source" -ForegroundColor Green
            } else {
                Copy-Item -Path $Source -Destination $Target -Force
                Write-Host "Copied $Source to $Target (symbolic links require admin rights)" -ForegroundColor Yellow
            }
        } else {
            New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
            Write-Host "Created symbolic link: $Target -> $Source" -ForegroundColor Green
        }
    } catch {
        Copy-Item -Path $Source -Destination $Target -Force
        Write-Host "Copied $Source to $Target (symbolic links not supported)" -ForegroundColor Yellow
    }
}
$redirectContent = @'
// This file redirects to the configuration in .github/linting
module.exports = require("./.github/linting/.markdownlintrc");
'@
Set-Content -Path ".markdownlintrc.js" -Value $redirectContent
Write-Host "Created .markdownlintrc.js redirect to .github/linting/.markdownlintrc" -ForegroundColor Green
foreach ($file in $configFiles) {
    if (Test-Path $file.Source) {
        Sync-File -Source $file.Source -Target $file.Target
    } else {
        Write-Host "Warning: Source file $($file.Source) not found" -ForegroundColor Yellow
    }
}
Write-Host "Markdown linting configuration sync complete!" -ForegroundColor Green
Write-Host "Root configuration files are now linked to .github/linting"
'@

$runMarkdownLintContent = @'
# Script to run markdown linting on the repository
param(
    [string]$ConfigPath = ".markdownlint-cli2.jsonc",
    [string]$TargetPath = ".github/**/*.md",
    [switch]$Fix,
    [switch]$Help
)

# Show help if requested
if ($Help) {
    Write-Host "Usage: .\run-markdown-lint.ps1 [-ConfigPath <path>] [-TargetPath <glob>] [-Fix] [-Help]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -ConfigPath <path>   Path to config file (default: .markdownlint-cli2.jsonc)"
    Write-Host "  -TargetPath <glob>   Glob pattern for files to lint (default: .github/**/*.md)"
    Write-Host "  -Fix                 Fix linting issues where possible"
    Write-Host "  -Help                Show this help message"
    Write-Host ""
    Write-Host "Related Scripts:"
    Write-Host "  .\run-lint-check.ps1        Validate the linting configuration"
    Write-Host "  .\sync-config.ps1           Sync linting config to root directory"
    Write-Host "  .\update-spell-checker.ps1  Update spell checker with linting terms"
    exit 0
}

# Ensure we're in the repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
}

# Check if config exists in current location
if (-not (Test-Path $ConfigPath)) {
    # Check if config exists in .github/linting
    $altConfigPath = Join-Path ".github" "linting" $ConfigPath
    if (Test-Path $altConfigPath) {
        Write-Host "Using configuration from $altConfigPath"
        $ConfigPath = $altConfigPath
    } else {
        Write-Host "Configuration file not found: $ConfigPath or $altConfigPath" -ForegroundColor Red
        exit 1
    }
}

# Run linting
Write-Host "Running markdown linting with config: $ConfigPath"
Write-Host "Target paths: $TargetPath"
Write-Host ""

if ($Fix) {
    & npx markdownlint-cli2 $TargetPath --config $ConfigPath --fix
} else {
    & npx markdownlint-cli2 $TargetPath --config $ConfigPath
}

# Return the exit code from markdownlint
exit $LASTEXITCODE
'@

# This base64 block decodes a small bash script for Unix-like systems
$encodedRunMarkdownLintSh = 'IyEgL2Jpbi9iYXNoCiMgU2NyaXB0IHRvIHJ1biBtYXJrZG93biBsaW50aW5nIG9uIHRoZSByZXBvc2l0b3J5CgpzZXQgLWUKCkNPTkZJR19QQVRIPSIuZ2l0aHViL2xpbnRpbmcvLm1hcmtkb3dubGluZC1jbGkyLmpzb25jIgpUQVJHRVRfUEFUSFM9Ii5naXRodWIvKi8qKi5tZCIKRklYPXRydWUKd2hpbGUgWyAkIyAtZ3QgMCAkXmRvIF07IGRvCiAgY2FzZSAiJDEiIGluCiAgICAtLWNvbmZpZykKICAgICAgQ09ORklHX1BBVEg9IiQyIgogICAgICBzaGlmdCAyCiAgICAtLXRhcmdldCkKICAgICAgVEFSR0VUX1BBVEhTPSIkMiIKICAgICAgc2hpZnQgMgogICAgICBzbGlmdCBgCiAgICAtLWZpeCkKICAgICAgRklYPXRydWUKICAgICAgc2hpZnQgMQogICAgICBzbGlmdCBgCiAgICAtLWhlbHApCiAgICAg IGVjaG8gIlVzYWdlOiAuL3J1bi1tYXJrZG93bi1saW50LnNo IFstLWNvbmZpZyA8cGF0aD5d IFstLXRhcmdldCA8Z2xvYl0gXVsKICAgICAgZWNobyAiIgogICAgICBlY2hvICJPcHRpb25zOiIKICAgICAgZWNobyAiICAtLWNvbmZpZyA8cGF0aD4gICBQYXRoIHRvIGNvbmZpZyBmaWxlIChkZWZhdWx0OiAuZ2l0aHViL2xpbnRpbmcvLm1hcmtkb3dubGluZC1jbGkyLmpzb25jKSIKICAgICAgZWNobyAiICAtLXRhcmdldCA8Z2xvYj4gICBHbG9iIHBhdHRlcm4gZm9yIGZpbGVzIHRvIGxpbnQgKGRlZmF1bHQ6 IC5naXRodWIvKi8qKi5tZCkiCiAgICAgIGVjaG8gIiAgLS1maXggICAgICAgICAgRml4IGxpbnRpbmcgaXNzdWVzIHdoZXJlIHBvc3NpYmxlIgogICAgICBlY2hvICIgIC0taGVscCAgICAgICAgICAgIFNob3cgdGhpcyBoZWxwIG1lc3NhZ2UiCiAgICAg IGV4aXQgMCAKICAgICAgOzsKICAgICopCiAgICAg IHNoaWZ0IDIKICAgICAgOzsKICAgIGVzYWMKZG9uZQplY2hvICJSdW5uaW5nIG1hcmtkb3duIGxpbnRpbmcgd2l0aCBjb25maWc6ICRDT05GSUdfUEFUSCIKZWNobyAiVGFyZ2V0IHBhdGhzOiAkVEFSR0VUX1BBVEhzIgoKifsgIiRGSVgi ID0gdHJ1ZSBdOyB0aGVuCiAgbnB4IG1hcmtkb3dubGludC1jbGky ICIkVEFSR0VUX1BBVEhzIi AtLWNvbmZpZy AiJENPTkZJR19QQVRIIi AtLWZpeAplbHNlCiAgbnB4IG1hcmtkb3dubGludC1jbGky ICIkVEFSR0VUX1BBVEhzIi AtLWNvbmZpZy AiJENPTkZJR19QQVRIIgpmaQp4aXQgMCAgCg=='
$runMarkdownLintShContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedRunMarkdownLintSh))

$runLintCheckContent = @'
# Lint Check Utility Script
# This script helps verify that the linting configuration files are working properly

param (
    [switch]$Fix,
    [switch]$Help
)

if ($Help) {
    Write-Host "Lint Check Utility"
    Write-Host "Usage: ./run-lint-check.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Fix       Fix linting issues where possible"
    Write-Host "  -Help      Show this help message"
    exit 0
}

# Change to repo root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
} else {
    Write-Host "Not in a git repository! Please run this script from the repository root." -ForegroundColor Red
    exit 1
}

Write-Host "=== Markdown Linting Configuration Validation ===" -ForegroundColor Cyan

# Verify the .github/linting directory
Write-Host "`nChecking .github/linting directory..." -ForegroundColor Yellow
if (Test-Path .github/linting) {
    $lintingFiles = Get-ChildItem .github/linting -File | ForEach-Object { $_.Name }
    Write-Host "Found $(($lintingFiles | Measure-Object).Count) files in .github/linting:" -ForegroundColor Green
    $lintingFiles | ForEach-Object { Write-Host "  - $_" }
} else {
    Write-Host "ERROR: .github/linting directory not found!" -ForegroundColor Red
    exit 1
}

# Check for the presence of required configuration files
Write-Host "`nChecking for required configuration files..." -ForegroundColor Yellow
$requiredFiles = @(
    ".github/linting/.markdownlint-cli2.jsonc",
    ".github/linting/.markdownlint.json",
    ".github/linting/.markdownlintignore",
    ".github/linting/.markdownlintrc",
    ".github/linting/README.md",
    ".github/linting/run-markdown-lint.ps1",
    ".github/linting/run-markdown-lint.sh",
    ".github/linting/sync-config.ps1",
    ".github/linting/update-spell-checker.ps1"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file" -ForegroundColor Red
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "`nWARNING: Missing required files:" -ForegroundColor Red
    $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
} else {
    Write-Host "`nAll required files are present!" -ForegroundColor Green
}

# Check for synced files in the root directory
Write-Host "`nChecking for synced files in the root directory..." -ForegroundColor Yellow
$rootFiles = @(
    ".markdownlint-cli2.jsonc",
    ".markdownlint.json",
    ".markdownlintignore",
    ".markdownlintrc"
)

$unsynced = $false
foreach ($file in $rootFiles) {
    $githubVersion = ".github/linting/$file"

    if (-not (Test-Path $file)) {
        Write-Host "  ✗ $file does not exist in the root directory" -ForegroundColor Red
        $unsynced = $true
        continue
    }

    if (-not (Test-Path $githubVersion)) {
        Write-Host "  ✗ $githubVersion does not exist" -ForegroundColor Red
        $unsynced = $true
        continue
    }

    $rootContent   = Get-Content $file -Raw
    $githubContent = Get-Content $githubVersion -Raw

    if ($rootContent -ne $githubContent) {
        Write-Host "  ✗ $file is not in sync with $githubVersion" -ForegroundColor Red
        $unsynced = $true
    } else {
        Write-Host "  ✓ $file is in sync with $githubVersion" -ForegroundColor Green
    }
}

if ($unsynced) {
    Write-Host "`nWARNING: Some files are not in sync!" -ForegroundColor Red
    Write-Host "Run the sync script to fix this issue:" -ForegroundColor Yellow
    Write-Host "  pwsh .github/linting/sync-config.ps1" -ForegroundColor Yellow

    if ($Fix) {
        Write-Host "`nAttempting to fix sync issues..." -ForegroundColor Yellow
        & ".github/linting/sync-config.ps1"
    }
} else {
    Write-Host "`nAll files are properly synced!" -ForegroundColor Green
}

# Check if markdownlint-cli2 is installed
Write-Host "`nChecking for markdownlint-cli2..." -ForegroundColor Yellow
$markdownlintInstalled = $null -ne (Get-Command npx -ErrorAction SilentlyContinue)

if ($markdownlintInstalled) {
    Write-Host "  ✓ npx is available, testing markdownlint-cli2..." -ForegroundColor Green

    $testResult = $null
    try {
        $testResult = npx markdownlint-cli2 --version 2>&1
        if ($testResult -match "markdownlint-cli2") {
            Write-Host "  ✓ markdownlint-cli2 is installed: $testResult" -ForegroundColor Green

            # Test lint on one file
            Write-Host "`nTesting linting on README.md..." -ForegroundColor Yellow
            & pwsh .github/linting/run-markdown-lint.ps1 -TargetPath ".github/linting/README.md"
        } else {
            Write-Host "  ✗ markdownlint-cli2 test failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ✗ markdownlint-cli2 is not installed" -ForegroundColor Red
        Write-Host "    Run 'npm install -g markdownlint-cli2' to install it" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✗ npx is not available" -ForegroundColor Red
    Write-Host "    Install Node.js to use markdownlint-cli2" -ForegroundColor Yellow
}

Write-Host "`n=== Validation complete ===" -ForegroundColor Cyan
'@

$updateSpellCheckerContent = @'
Set-Location (git rev-parse --show-toplevel)
$settingsPath = ".vscode/settings.json"
$settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
$lintingWords = @(
    "markdownlint",
    "markdownlintrc",
    "markdownlintignore",
    "markdownlintcli2"
)
$existingWords = $settings.'cSpell.words'
$newWords = @()
foreach ($word in $lintingWords) {
    if ($existingWords -notcontains $word) {
        $newWords += $word
    }
}
if ($newWords.Count -gt 0) {
    $settings.'cSpell.words' = ($existingWords + $newWords) | Sort-Object
    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath
}
$dictionaryPath = ".config/cspell-dictionary.txt"
if (Test-Path $dictionaryPath) {
    $dictionary = Get-Content -Path $dictionaryPath
    $newDictionaryEntries = @()
    foreach ($word in $lintingWords) {
        if ($dictionary -notcontains $word) {
            $newDictionaryEntries += $word
        }
    }
    if ($newDictionaryEntries.Count -gt 0) {
        $newDictionaryEntries | Add-Content -Path $dictionaryPath
        $dictionary = Get-Content -Path $dictionaryPath | Sort-Object
        $dictionary | Set-Content -Path $dictionaryPath
    }
}
Write-Host "Spell checker configuration update complete!"
'@

$readmeContent = @'
# Markdown Linting Configuration
This directory holds the markdown linting configuration for the project.
'@

$tasksContent = @'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Markdown Lint Check",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-File",
                "${workspaceFolder}/.github/linting/run-markdown-lint.ps1"
            ],
            "group": {
                "kind": "test",
                "isDefault": false
            },
            "presentation": {
                "reveal": "always",
                "panel": "new"
            },
            "problemMatcher": []
        },
        {
            "label": "Markdown Fix Issues",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-File",
                "${workspaceFolder}/.github/linting/run-markdown-lint.ps1",
                "-Fix"
            ],
            "group": {
                "kind": "build",
                "isDefault": false
            },
            "presentation": {
                "reveal": "always",
                "panel": "new"
            },
            "problemMatcher": []
        },
        {
            "label": "Validate Linting Configuration",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-File",
                "${workspaceFolder}/.github/linting/run-lint-check.ps1"
            ],
            "group": {
                "kind": "test",
                "isDefault": false
            },
            "presentation": {
                "reveal": "always",
                "panel": "new"
            },
            "problemMatcher": []
        }
    ]
}
'@

$workflowContent = @'
name: Markdown Linting

on:
  push:
    branches: [ main ]
    paths:
      - '**/*.md'
      - '.github/linting/**'
      - '.github/workflows/markdown-lint.yml'
  pull_request:
    branches: [ main ]
    paths:
      - '**/*.md'
      - '.github/linting/**'
      - '.github/workflows/markdown-lint.yml'
  workflow_dispatch:

jobs:
  lint-markdown:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install markdownlint-cli2
        run: npm install -g markdownlint-cli2

      - name: Run lint check on GitHub markdown files
        run: markdownlint-cli2 .github/**/*.md --config .markdownlint-cli2.jsonc

      - name: Run lint check on documentation
        run: markdownlint-cli2 docs/**/*.md --config .markdownlint-cli2.jsonc

      - name: Run lint check on root markdown files
        run: markdownlint-cli2 *.md --config .markdownlint-cli2.jsonc
'@

# ----------------------------------------------------------------
# Write all config files to .github/linting plus the workflow file
# ----------------------------------------------------------------
$configFiles = @(
    @{ Path = ".github/linting/.markdownlint-cli2.jsonc"; Content = $markdownlintCli2Content },
    @{ Path = ".github/linting/.markdownlint.json";      Content = $markdownlintJsonContent },
    @{ Path = ".github/linting/.markdownlintignore";     Content = $markdownlintIgnoreContent },
    @{ Path = ".github/linting/.markdownlintrc";         Content = $markdownlintrcContent },
    @{ Path = ".github/linting/sync-config.ps1";         Content = $syncConfigContent },
    @{ Path = ".github/linting/run-markdown-lint.ps1";   Content = $runMarkdownLintContent },
    @{ Path = ".github/linting/run-markdown-lint.sh";    Content = $runMarkdownLintShContent },
    @{ Path = ".github/linting/run-lint-check.ps1";      Content = $runLintCheckContent },
    @{ Path = ".github/linting/update-spell-checker.ps1";Content = $updateSpellCheckerContent },
    @{ Path = ".github/linting/README.md";               Content = $readmeContent },
    @{ Path = ".github/linting/markdown-tasks.code-tasks"; Content = $tasksContent },
    @{ Path = ".github/workflows/markdown-lint.yml";     Content = $workflowContent }
)

foreach ($file in $configFiles) {
    if (Test-Path $file.Path) {
        if (-not $Force) {
            $response = Read-Host "File $($file.Path) already exists. Overwrite? (y/n)"
            if ($response -ne "y") {
                Write-Host "Skipping $($file.Path)" -ForegroundColor Yellow
                continue
            }
        }
        Write-Host "Overwriting $($file.Path)" -ForegroundColor Yellow
    } else {
        Write-Host "Creating $($file.Path)" -ForegroundColor Green
    }
    Set-Content -Path $file.Path -Value $file.Content
}

if (Test-Path "$lintingDir/run-markdown-lint.sh") {
    Write-Host "Note: If using on Unix/Linux, run chmod +x $lintingDir/run-markdown-lint.sh" -ForegroundColor Yellow
}

# ----------------------------------------------------------------
# Optional cleanup of root configuration files and redirect creation
# ----------------------------------------------------------------
if ($CleanupRoot) {
    Write-Host "`nRemoving root configuration files and creating redirects..." -ForegroundColor Cyan

    $rootFiles = @(
        ".markdownlint-cli2.jsonc",
        ".markdownlint.json",
        ".markdownlintignore",
        ".markdownlintrc"
    )
    foreach ($file in $rootFiles) {
        if (Test-Path $file) {
            Write-Host "Removing $file from root directory..." -ForegroundColor Yellow
            Remove-Item -Path $file -Force
        }
    }

    # Example redirect file for .markdownlintrc.js in the root
    $redirectContent = @'
// This file redirects to the configuration in .github/linting
module.exports = require("./.github/linting/.markdownlintrc");
'@
    Write-Host "Creating .markdownlintrc.js redirect to .github/linting/.markdownlintrc" -ForegroundColor Green
    Set-Content -Path ".markdownlintrc.js" -Value $redirectContent

    Write-Host "Root cleanup and redirects complete." -ForegroundColor Green
}

Write-Host "All tasks completed successfully." -ForegroundColor Green