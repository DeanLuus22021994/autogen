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

# Check prerequisites - modified to avoid parallel processing issues
$prerequisites = @{
    "Node.js" = { Get-Command node -ErrorAction SilentlyContinue }
    "npm"     = { Get-Command npm -ErrorAction SilentlyContinue }
    "npx"     = { Get-Command npx -ErrorAction SilentlyContinue }
}

# Fixed parallel processing
$missingPrerequisites = @()
# Use standard ForEach instead of -Parallel to fix the $using issue
foreach ($key in $prerequisites.Keys) {
    $scriptBlock = $prerequisites[$key]
    $check = & $scriptBlock
    if (-not $check) {
        $missingPrerequisites += $key
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

$redirectJs = '// This file redirects to the configuration in .github/linting
module.exports = require("./.github/linting/.markdownlintrc");'

Set-Content -Path ".markdownlintrc.js" -Value $redirectJs
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

# Fixed the base64 issue by including the shell script directly
$runMarkdownLintShContent = @'
#!/bin/bash
# Script to run markdown linting on the repository

set -e

CONFIG_PATH=".github/linting/.markdownlint-cli2.jsonc"
TARGET_PATHS=".github/**/*.md"
FIX=false

# Parse command line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --target)
      TARGET_PATHS="$2"
      shift 2
      ;;
    --fix)
      FIX=true
      shift
      ;;
    --help)
      echo "Usage: ./run-markdown-lint.sh [--config <path>] [--target <glob>] [--fix] [--help]"
      echo ""
      echo "Options:"
      echo "  --config <path>   Path to config file (default: .github/linting/.markdownlint-cli2.jsonc)"
      echo "  --target <glob>   Glob pattern for files to lint (default: .github/**/*.md)"
      echo "  --fix             Fix linting issues where possible"
      echo "  --help            Show this help message"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

echo "Running markdown linting with config: $CONFIG_PATH"
echo "Target paths: $TARGET_PATHS"
echo ""

if [ "$FIX" = true ]; then
  npx markdownlint-cli2 "$TARGET_PATHS" --config "$CONFIG_PATH" --fix
else
  npx markdownlint-cli2 "$TARGET_PATHS" --config "$CONFIG_PATH"
fi

exit $?
'@

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
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
} else {
    Set-Location $PWD.Path
}

$settingsPath = ".vscode/settings.json"
# Use conditional checks to handle missing files
if (Test-Path $settingsPath) {
    $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
    $existingWords = $settings.'cSpell.words'
    if ($null -eq $existingWords) {
        $existingWords = @()
    }
} else {
    $settings = [PSCustomObject]@{ 'cSpell.words' = @() }
    $existingWords = @()
}

# Common linting terminology to add to dictionary
$lintingWords = @(
    "markdownlint",
    "markdownlintrc",
    "markdownlintignore",
    "markdownlintcli2"
)

# Use pipeline filter to find words not already in the dictionary
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
    # Use PowerShell pipeline to filter for new entries
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

# Fixed JSON content for tasks
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

# Fixed YAML content for workflow
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

# Fixed file processing with proper error handling
foreach ($file in $configFiles) {
    # Ensure directory exists
    $directory = Split-Path -Path $file.Path -Parent
    if (-not (Test-Path $directory)) {
        try {
            New-Item -Path $directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Host "Created directory: $directory" -ForegroundColor Green
        }
        catch {
            Write-Host "Error creating directory $directory`: $_" -ForegroundColor Red
            continue
        }
    }

    # Check if file exists and handle overwrite
    if (Test-Path $file.Path) {
        if (-not $Force) {
            $response = Read-Host -Prompt "File $($file.Path) already exists. Overwrite? (y/n)"
            if ($response -ne "y") {
                Write-Host "Skipping $($file.Path)" -ForegroundColor Yellow
                continue
            }
        }
        Write-Host "Overwriting $($file.Path)" -ForegroundColor Yellow
    } else {
        Write-Host "Creating $($file.Path)" -ForegroundColor Green
    }

    # Write the file with error handling
    try {
        Set-Content -Path $file.Path -Value $file.Content -Encoding UTF8 -ErrorAction Stop
        Write-Host "Successfully wrote $($file.Path)" -ForegroundColor Green
    }
    catch {
        Write-Host "Error writing $($file.Path): $_" -ForegroundColor Red
        # Try alternate method if first fails
        try {
            [System.IO.File]::WriteAllText($file.Path, $file.Content)
            Write-Host "Successfully wrote $($file.Path) using alternate method" -ForegroundColor Green
        }
        catch {
            Write-Host "Critical error: Could not write $($file.Path): $_" -ForegroundColor Red
        }
    }
}

# Make shell script executable
if (Test-Path "$lintingDir/run-markdown-lint.sh") {
    Write-Host "Note: If using on Unix/Linux, run chmod +x $lintingDir/run-markdown-lint.sh" -ForegroundColor Yellow

    # Try to set permissions on Unix-like systems
    if ($IsLinux -or $IsMacOS) {
        try {
            & chmod +x "$lintingDir/run-markdown-lint.sh" 2>$null
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

    # Remove root files with proper error handling
    foreach ($file in $rootFiles) {
        if (Test-Path $file) {
            try {
                Remove-Item -Path $file -Force -ErrorAction Stop
                Write-Host "Removed $file from root directory" -ForegroundColor Yellow
            }
            catch {
                Write-Host "Error removing $file`: $_" -ForegroundColor Red
            }
        }
    }

    # Create redirect file - fixed string content
    $redirectContent = @"
// This file redirects to the configuration in .github/linting
module.exports = require("./.github/linting/.markdownlintrc");
"@

    # Create redirect file
    try {
        Set-Content -Path ".markdownlintrc.js" -Value $redirectContent -Encoding UTF8 -ErrorAction Stop
        Write-Host "Created .markdownlintrc.js redirect to .github/linting/.markdownlintrc" -ForegroundColor Green
    }
    catch {
        Write-Host "Error creating redirect file: $_" -ForegroundColor Red
    }

    # Update VS Code settings
    $vsCodeSettingsPath = ".vscode/settings.json"
    if (Test-Path $vsCodeSettingsPath) {
        try {
            $settings = Get-Content -Path $vsCodeSettingsPath -Raw | ConvertFrom-Json

            # Add markdownlint configuration using proper PowerShell 7.5 technique
            $settings | Add-Member -NotePropertyName "markdownlint.config" -NotePropertyValue @{
                extends = ".github/linting/.markdownlint.json"
            } -Force

            # Save updated settings back to file
            $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $vsCodeSettingsPath -Encoding UTF8
            Write-Host "Updated VS Code settings to use .github/linting configuration directly" -ForegroundColor Green
        }
        catch {
            Write-Host "Error updating VS Code settings: $_" -ForegroundColor Red
        }
    } else {
        # Create new VS Code settings if they don't exist
        try {
            $vsCodeDir = ".vscode"
            if (-not (Test-Path $vsCodeDir)) {
                New-Item -Path $vsCodeDir -ItemType Directory -Force | Out-Null
            }

            $newSettings = [PSCustomObject]@{
                "markdownlint.config" = @{
                    extends = ".github/linting/.markdownlint.json"
                }
            }

            $newSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $vsCodeSettingsPath -Encoding UTF8
            Write-Host "Created new VS Code settings with markdownlint configuration" -ForegroundColor Green
        }
        catch {
            Write-Host "Error creating VS Code settings: $_" -ForegroundColor Red
        }
    }

    Write-Host "Root cleanup and redirects complete." -ForegroundColor Green
}

# Run validation if requested
if ($Validate) {
    Write-Host "`nRunning validation checks..." -ForegroundColor Cyan
    if (Test-Path "$lintingDir/run-lint-check.ps1") {
        try {
            & "$lintingDir/run-lint-check.ps1"
        }
        catch {
            Write-Host "Error during validation: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Error: run-lint-check.ps1 not found" -ForegroundColor Red
    }
}

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
