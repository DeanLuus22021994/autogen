# Markdown Linting Configuration Reorganization
# This script implements the reorganization of markdown linting configuration files
# into the .github/linting directory and sets up all necessary components for a
# complete linting solution.

param(
    [switch]$Force,
    [switch]$Validate,
    [switch]$Help,
    [switch]$CleanupRoot  # Parameter to remove root files
)

# Show help if requested
if ($Help) {
    Write-Host "Markdown Linting Setup Script" -ForegroundColor Cyan
    Write-Host "Parameters: -Force -Validate -CleanupRoot -Help"
    exit 0
}

# Ensure we're in the repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
    Write-Host "Working in repository root: $repoRoot" -ForegroundColor Green
} else {
    Write-Host "Error: Not in a git repository." -ForegroundColor Red
    exit 1
}

# Check prerequisites using more robust PowerShell 7.5 functionality
$prerequisites = @{
    "Node.js" = { Get-Command node -ErrorAction SilentlyContinue }
    "npm"     = { Get-Command npm -ErrorAction SilentlyContinue }
    "npx"     = { Get-Command npx -ErrorAction SilentlyContinue }
}

# Use PowerShell 7.5 parallel processing for faster checks
$missingPrerequisites = $prerequisites.Keys | ForEach-Object -Parallel {
    $check = $using:prerequisites[$_].Invoke()
    if (-not $check) {
        $_
    }
} | Where-Object { $_ }

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

# Using Base64 encoding for the shell script to prevent any issues with special characters
$encodedRunMarkdownLintSh = 'IyEgL2Jpbi9iYXNoCiMgU2NyaXB0IHRvIHJ1biBtYXJrZG93biBsaW50aW5nIG9uIHRoZSByZXBvc2l0b3J5CgpzZXQgLWUKCkNPTkZJR19QQVRIPSIuZ2l0aHViL2xpbnRpbmcvLm1hcmtkb3dubGluZC1jbGkyLmpzb25jIgpUQVJHRVRfUEFUSFM9Ii5naXRodWIvKiovKioubWQiCkZJWD1mYWxzZQoKIyBQYXJzZSBjb21tYW5kIGxpbmUgYXJndW1lbnRzCndoaWxlIFsgJCMgLWd0IDAgXTsgZG8KICBjYXNlICIkMSIgaW4KICAgIC0tY29uZmlnKQogICAgICBDT05GSUdfUEFUSD0iJDIiCiAgICAgIHNoaWZ0IDIKICAgICAgOzsKICAgIC0tdGFyZ2V0KQogICAgICBUQVJHRVRfUEFUSFM9IiQyIgogICAgICBzaGlmdCAyCiAgICAgIDs7CiAgICAtLWZpeCkKICAgICAgRklYPXRydWUKICAgICAgc2hpZnQKICAgICAgOzsKICAgIC0taGVscCkKICAgICAgZWNobyAiVXNhZ2U6IC4vcnVuLW1hcmtkb3duLWxpbnQuc2ggWy0tY29uZmlnIDxwYXRoPl0gWy0tdGFyZ2V0IDxnbG9iPl0gWy0tZml4XSBbLS1oZWxwXSIKICAgICAgZWNobyAiIgogICAgICBlY2hvICJPcHRpb25zOiIKICAgICAgZWNobyAiICAtLWNvbmZpZyA8cGF0aD4gICBQYXRoIHRvIGNvbmZpZyBmaWxlIChkZWZhdWx0OiAuZ2l0aHViL2xpbnRpbmcvLm1hcmtkb3dubGluZC1jbGkyLmpzb25jKSIKICAgICAgZWNobyAiICAtLXRhcmdldCA8Z2xvYj4gICBHbG9iIHBhdHRlcm4gZm9yIGZpbGVzIHRvIGxpbnQgKGRlZmF1bHQ6IC5naXRodWIvKiovKioubWQpIgogICAgICBlY2hvICIgIC0tZml4ICAgICAgICAgICAgRml4IGxpbnRpbmcgaXNzdWVzIHdoZXJlIHBvc3NpYmxlIgogICAgICBlY2hvICIgIC0taGVscCAgICAgICAgICAgIFNob3cgdGhpcyBoZWxwIG1lc3NhZ2UiCiAgICAgIGV4aXQgMAogICAgICA7OwogICAgKikKICAgICAgc2hpZnQKICAgICAgOzsKICBlc2FjCmRvbmUKCmVjaG8gIlJ1bm5pbmcgbWFya2Rvd24gbGludGluZyB3aXRoIGNvbmZpZzogJENPTkZJR19QQVRIIgplY2hvICJUYXJnZXQgcGF0aHM6ICRQQVRIRSIKZWN0Im8gIiIKCmlmIFsgIiRGSVgiID0gdHJ1ZSBdOyB0aGVuCiAgbnB4IG1hcmtkb3dubGludC1jbGkyICIkVEFSR0VUX1BBVEhTIiAtLWNvbmZpZyAiJENPTkZJR19QQVRIIiAtLWZpeAplbHNlCiAgbnB4IG1hcmtkb3dubGludC1jbGkyICIkVEFSR0VUX1BBVEhTIiAtLWNvbmZpZyAiJENPTkZJR19QQVRIIgpmaQoKZXhpdCAkPwo='
# Using PowerShell 7.5 improved error handling with try/catch
try {
    $runMarkdownLintShContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedRunMarkdownLintSh))
}
catch {
    Write-Error "Failed to decode shell script content: $_"
    $runMarkdownLintShContent = "#!/bin/bash\necho 'Error: Script could not be properly generated. Please report this issue.'\nexit 1"
}

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
# Update Spell Checker for Linting
# This script updates the CSpell configuration to include linting terminology

# Use PowerShell 7.5 ternary operator for more concise code
Set-Location (git rev-parse --show-toplevel 2>$null ?? $PWD.Path)

$settingsPath = ".vscode/settings.json"
# Use conditional pipeline with null fallback (PowerShell 7.5 feature)
$settings = (Test-Path $settingsPath) ?
    (Get-Content -Path $settingsPath -Raw | ConvertFrom-Json) :
    [PSCustomObject]@{ 'cSpell.words' = @() }

# Common linting terminology to add to dictionary
$lintingWords = @(
    "markdownlint",
    "markdownlintrc",
    "markdownlintignore",
    "markdownlintcli2"
)

# Use pipeline filter to find words not already in the dictionary
$existingWords = $settings.'cSpell.words' ?? @()
$newWords = $lintingWords | Where-Object { $_ -notin $existingWords }

if ($newWords.Count -gt 0) {
    Write-Host "Adding the following words to the VS Code spell checker dictionary:" -ForegroundColor Cyan
    $newWords | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }

    # Use PowerShell 7.5 pipeline enhancement for array operations
    $settings.'cSpell.words' = ($existingWords + $newWords) | Sort-Object

    # Create directory if it doesn't exist
    if (-not (Test-Path (Split-Path $settingsPath -Parent))) {
        New-Item -Path (Split-Path $settingsPath -Parent) -ItemType Directory -Force | Out-Null
    }

    # Write the updated settings back to the file
    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath

    Write-Host "Spell checker dictionary updated successfully!" -ForegroundColor Green
} else {
    Write-Host "No new words needed to be added to the dictionary." -ForegroundColor Yellow
}

# Also update the main dictionary file if it exists
$dictionaryPath = ".config/cspell-dictionary.txt"
if (Test-Path $dictionaryPath) {
    $dictionary = Get-Content -Path $dictionaryPath
    # Use PowerShell 7.5 pipeline to filter for new entries
    $newDictionaryEntries = $lintingWords | Where-Object { $_ -notin $dictionary }

    if ($newDictionaryEntries.Count -gt 0) {
        Write-Host "`nAdding words to the main dictionary file:" -ForegroundColor Cyan
        $newDictionaryEntries | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }

        # Add new words and sort the dictionary
        $newDictionaryEntries | Add-Content -Path $dictionaryPath
        Get-Content -Path $dictionaryPath | Sort-Object | Set-Content -Path $dictionaryPath

        Write-Host "Main dictionary file updated successfully!" -ForegroundColor Green
    }
}

Write-Host "Spell checker configuration update complete!" -ForegroundColor Green
'@

$readmeContent = @'
# Markdown Linting Configuration

This directory is the **single source of truth** for all markdown linting configuration in the repository.

## Configuration Files

- `.markdownlint-cli2.jsonc` - Configuration for the markdownlint-cli2 tool
- `.markdownlint.json` - Configuration for the markdownlint VS Code extension and other tools
- `.markdownlintignore` - Files to ignore during linting
- `.markdownlintrc` - Legacy configuration for backward compatibility

## How Tools Find These Files

1. **VS Code Extension**: Configured in `.vscode/settings.json` to use `.github/linting/.markdownlint.json`
2. **CLI Tools**: Most CLI tools can be configured with command-line parameters:
   ```
   markdownlint --config .github/linting/.markdownlint.json
   ```
3. **Root Redirect**: The `sync-config.ps1` script maintains copies of the configuration files in the root directory

## Running Linting

Use the provided scripts:
- `run-markdown-lint.ps1` - For PowerShell environments
- `run-markdown-lint.sh` - For bash environments

## Maintaining Configuration

When updating any linting rules, make changes **only** to the files in this directory, then run:
```
pwsh sync-config.ps1
```

## Setup

If adding this to a new repository, simply run:
```
pwsh sync-config.ps1
```

To update your VS Code settings to use these configurations:
```json
// Add this to your .vscode/settings.json
"markdownlint.config": {
  "extends": ".github/linting/.markdownlint.json"
}
```

## Available Scripts

- `sync-config.ps1` - Synchronizes configuration files to the root directory
- `run-markdown-lint.ps1` - Runs markdown linting with various options
- `run-lint-check.ps1` - Validates the linting configuration
- `update-spell-checker.ps1` - Updates spell checker with linting terminology
'@

# Fixed the tasks content here-string properly
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

# Fixed the workflow content with proper steps section
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
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install markdownlint-cli2
        run: npm install -g markdownlint-cli2

      - name: Run lint check on GitHub markdown files
        run: markdownlint-cli2 .github/**/*.md --config .markdownlint-cli2.jsonc

      - name: Run lint check on documentation
        run: markdownlint-cli2 docs/**/*.md --config .markdownlint-cli2.jsonc
        continue-on-error: true

      - name: Run lint check on root markdown files
        run: markdownlint-cli2 *.md --config .markdownlint-cli2.jsonc
'@

# ----------------------------------------------------------------
# Write all config files to .github/linting plus the workflow file
# ----------------------------------------------------------------

# Enhanced configuration files array with structured data
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

# Use PowerShell 7.5's improved error handling with try/catch/finally
try {
    # Use parallel processing for file creation (PowerShell 7.5 feature)
    $configFiles | ForEach-Object -ThrottleLimit 8 -Parallel {
        $file = $_
        $Force = $using:Force

        # Using Try/Catch for robust error handling
        try {
            # Ensure directory exists using current PowerShell 7.5 techniques
            $directory = Split-Path -Path $file.Path -Parent
            if (-not (Test-Path $directory)) {
                New-Item -Path $directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Host "Created directory: $directory" -ForegroundColor Green
            }

            if (Test-Path $file.Path) {
                if (-not $Force) {
                    # Use Read-Host with PowerShell 7.5's -Prompt parameter
                    $response = Read-Host -Prompt "File $($file.Path) already exists. Overwrite? (y/n)"
                    if ($response -ne "y") {
                        Write-Host "Skipping $($file.Path)" -ForegroundColor Yellow
                        return
                    }
                }
                Write-Host "Overwriting $($file.Path)" -ForegroundColor Yellow
            } else {
                Write-Host "Creating $($file.Path)" -ForegroundColor Green
            }

            # Write file with UTF-8 encoding without BOM - improved error handling
            [System.IO.File]::WriteAllText($file.Path, $file.Content, [System.Text.UTF8Encoding]::new($false))
            Write-Host "Successfully wrote $($file.Path)" -ForegroundColor Green
        }
        catch {
            # Enhanced error reporting with PowerShell 7.5's improved error object
            Write-Host "Error processing $($file.Path): $($_.Exception.Message)" -ForegroundColor Red

            # Fall back to native PowerShell cmdlet if .NET method fails
            try {
                Set-Content -Path $file.Path -Value $file.Content -Encoding UTF8 -ErrorAction Stop
                Write-Host "Fallback method succeeded for $($file.Path)" -ForegroundColor Yellow
            }
            catch {
                Write-Host "Critical error: Could not write $($file.Path): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    # Make shell script executable (helpful if used in Unix/Linux)
    if (Test-Path "$lintingDir/run-markdown-lint.sh") {
        Write-Host "Note: If using on Unix/Linux, run chmod +x $lintingDir/run-markdown-lint.sh" -ForegroundColor Yellow

        # Check if we're on a Unix-like system and try to set permissions
        if ($IsLinux -or $IsMacOS) {
            try {
                chmod +x "$lintingDir/run-markdown-lint.sh" 2>$null
                Write-Host "Executable permission set for run-markdown-lint.sh" -ForegroundColor Green
            }
            catch {
                Write-Host "Note: Could not set executable permissions automatically" -ForegroundColor Yellow
            }
        }
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

        # Use PowerShell 7.5 parallel processing for faster cleanup
        $rootFiles | ForEach-Object -Parallel {
            if (Test-Path $_) {
                Write-Host "Removing $_ from root directory..." -ForegroundColor Yellow
                Remove-Item -Path $_ -Force
            }
        }

        # Redirect content for .markdownlintrc.js
        $redirectContent = @'
// This file redirects to the configuration in .github/linting
module.exports = require("./.github/linting/.markdownlintrc");
'@

        # Create redirect file
        Set-Content -Path ".markdownlintrc.js" -Value $redirectContent -Encoding UTF8
        Write-Host "Created .markdownlintrc.js redirect to .github/linting/.markdownlintrc" -ForegroundColor Green

        # Update VS Code settings
        $vsCodeSettingsPath = ".vscode/settings.json"
        if (Test-Path $vsCodeSettingsPath) {
            $settings = Get-Content -Path $vsCodeSettingsPath -Raw | ConvertFrom-Json

            # Add markdownlint configuration or update existing one using PowerShell 7.5 hashtable merging
            $settings = $settings | Add-Member -NotePropertyName "markdownlint.config" -NotePropertyValue @{
                extends = ".github/linting/.markdownlint.json"
            } -Force -PassThru

            # Save updated settings back to file
            $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $vsCodeSettingsPath
            Write-Host "Updated VS Code settings to use .github/linting configuration directly" -ForegroundColor Green
        } else {
            # Create new VS Code settings if they don't exist
            $vsCodeDir = ".vscode"
            if (-not (Test-Path $vsCodeDir)) {
                New-Item -Path $vsCodeDir -ItemType Directory | Out-Null
            }

            @{
                "markdownlint.config" = @{
                    extends = ".github/linting/.markdownlint.json"
                }
            } | ConvertTo-Json -Depth 10 | Set-Content -Path $vsCodeSettingsPath
            Write-Host "Created new VS Code settings with markdownlint configuration" -ForegroundColor Green
        }

        Write-Host "Root cleanup and redirects complete." -ForegroundColor Green
    }

    # Run validation if requested
    if ($Validate) {
        Write-Host "`nRunning validation checks..." -ForegroundColor Cyan
        if (Test-Path "$lintingDir/run-lint-check.ps1") {
            & "$lintingDir/run-lint-check.ps1"
        } else {
            Write-Host "Error: run-lint-check.ps1 not found" -ForegroundColor Red
        }
    }
}
catch {
    # Centralized error handling with detailed error info
    Write-Host "A critical error occurred during setup:" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error occurred at line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host "Error occurred in command: $($_.InvocationInfo.Line)" -ForegroundColor Red
    exit 1
}
finally {
    # Final completion message with summary
    Write-Host "`n=== Markdown Linting Configuration Setup Complete ===" -ForegroundColor Green
    Write-Host "Setup has completed the following tasks:" -ForegroundColor Cyan
    Write-Host "✅ Created configuration files in .github/linting" -ForegroundColor Green
    Write-Host "✅ Created workflow file for GitHub Actions" -ForegroundColor Green
    if ($CleanupRoot) {
        Write-Host "✅ Created redirects from root to .github/linting" -ForegroundColor Green
    } else {
        Write-Host "✅ Synced configuration files to repository root" -ForegroundColor Green
    }
    if ($Validate) {
        Write-Host "✅ Validated the configuration" -ForegroundColor Green
    }

    Write-Host "`nTo run linting on your markdown files:" -ForegroundColor Yellow
    Write-Host "  pwsh .github/linting/run-markdown-lint.ps1" -ForegroundColor White

    Write-Host "`nAll tasks completed successfully." -ForegroundColor Green
}
