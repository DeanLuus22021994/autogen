Looking at the PowerShell script, I notice that the final line of the file appears to be incomplete or improperly formatted. Let me provide the full amended version of the `setup-markdown-linting.ps1` file with the corrected ending:

```powershell
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
    Write-Host "Markdown Linting Configuration Reorganization Script" -ForegroundColor Cyan
    Write-Host "This script implements a complete solution for organizing markdown linting configuration"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -Force       Override existing files without prompting"
    Write-Host "  -Validate    Run validation checks after setup"
    Write-Host "  -CleanupRoot Remove root configuration files and use redirects instead"
    Write-Host "  -Help        Show this help message"
    exit 0
}

# Ensure we're in the repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
    Write-Host "Working in repository root: $repoRoot" -ForegroundColor Green
} else {
    Write-Host "Error: Not in a git repository. Please run this script from a git repository." -ForegroundColor Red
    exit 1
}

# Check prerequisites
$prerequisites = @{
    "Node.js" = { Get-Command node -ErrorAction SilentlyContinue }
    "npm" = { Get-Command npm -ErrorAction SilentlyContinue }
    "npx" = { Get-Command npx -ErrorAction SilentlyContinue }
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

# Create necessary directories
$lintingDir = ".github/linting"
if (-not (Test-Path $lintingDir)) {
    Write-Host "Creating $lintingDir directory..." -ForegroundColor Yellow
    New-Item -Path $lintingDir -ItemType Directory -Force | Out-Null
    Write-Host "Directory created successfully." -ForegroundColor Green
} else {
    Write-Host "Directory $lintingDir already exists." -ForegroundColor Green
}

# ===============================
# Define Configuration File Content
# ===============================

# .markdownlint-cli2.jsonc content
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

# .markdownlint.json content
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

# .markdownlintignore content
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

# .markdownlintrc content
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

# sync-config.ps1 content
$syncConfigContent = @'
# Sync Markdown Linting Configuration
# This script syncs the markdown linting configuration files from .github/linting to the repository root
# using symbolic links where possible or file copies as fallback

# Ensure we're in the repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
}

# Define source and target files
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

# Function to create a symbolic link or copy file as fallback
function Sync-File {
    param (
        [string]$Source,
        [string]$Target
    )

    # If the target exists, remove it first
    if (Test-Path $Target) {
        Remove-Item $Target -Force
    }

    # Try to create a symbolic link
    try {
        if ($IsWindows -or $ENV:OS -match "Windows") {
            # On Windows, create a file symlink (requires admin or Developer Mode)
            $adminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

            if ($adminRights) {
                # Admin rights - can create symlink
                New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
                Write-Host "Created symbolic link: $Target -> $Source" -ForegroundColor Green
            } else {
                # No admin rights - copy the file instead
                Copy-Item -Path $Source -Destination $Target -Force
                Write-Host "Copied $Source to $Target (symbolic links require admin rights)" -ForegroundColor Yellow
            }
        } else {
            # On Unix/Linux, create a symbolic link
            New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
            Write-Host "Created symbolic link: $Target -> $Source" -ForegroundColor Green
        }
    } catch {
        # Fallback to copying the file
        Copy-Item -Path $Source -Destination $Target -Force
        Write-Host "Copied $Source to $Target (symbolic links not supported)" -ForegroundColor Yellow
    }
}

# Create .markdownlintrc.js redirect file in root
$redirectContent = @'
// This file redirects to the configuration in .github/linting
module.exports = require('./.github/linting/.markdownlintrc');
'@
Set-Content -Path ".markdownlintrc.js" -Value $redirectContent
Write-Host "Created .markdownlintrc.js redirect to .github/linting/.markdownlintrc" -ForegroundColor Green

# Sync each file
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

# run-markdown-lint.ps1 content
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

# run-markdown-lint.sh content
$runMarkdownLintShContent = @'
#!/bin/bash
# Script to run markdown linting on the repository

# Use bash error handling instead of PowerShell
set -e

# Default paths
CONFIG_PATH=".github/linting/.markdownlint-cli2.jsonc"
TARGET_PATHS=".github/**/*.md"

# Parse arguments using bash syntax
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
'@

# run-lint-check.ps1 content
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

    $rootContent = Get-Content $file -Raw
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

# update-spell-checker.ps1 content
$updateSpellCheckerContent = @'
# Update Spell Checker for Linting
# This script updates the CSpell configuration to include the new .github/linting directory

# Make sure we're in the right directory
Set-Location (git rev-parse --show-toplevel)

# Read the current VS Code settings
$settingsPath = ".vscode/settings.json"
$settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json

# Add linting-related words to the dictionary
$lintingWords = @(
    "markdownlint",
    "markdownlintrc",
    "markdownlintignore",
    "markdownlintcli2"
)

# Update the cSpell.words array with the new words
$existingWords = $settings.'cSpell.words'
$newWords = @()

foreach ($word in $lintingWords) {
    if ($existingWords -notcontains $word) {
        $newWords += $word
    }
}

if ($newWords.Count -gt 0) {
    Write-Host "Adding the following words to the VS Code spell checker dictionary:"
    $newWords | ForEach-Object { Write-Host "  - $_" }

    $settings.'cSpell.words' = ($existingWords + $newWords) | Sort-Object

    # Write back the updated settings
    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath

    Write-Host "Spell checker dictionary updated successfully."
} else {
    Write-Host "No new words needed to be added to the dictionary."
}

# Also add the words to the main dictionary file
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
        Write-Host "Adding words to the main dictionary file:"
        $newDictionaryEntries | ForEach-Object { Write-Host "  - $_" }

        $newDictionaryEntries | Add-Content -Path $dictionaryPath

        # Sort the dictionary file
        $dictionary = Get-Content -Path $dictionaryPath | Sort-Object
        $dictionary | Set-Content -Path $dictionaryPath

        Write-Host "Main dictionary file updated successfully."
    }
}

Write-Host "Spell checker configuration update complete!"
'@

# README.md content - Fix Markdown syntax issues by escaping special characters
$readmeContent = @'
# Markdown Linting Configuration

This directory is the **single source of truth** for all markdown linting configuration in the AutoGen project.

## Configuration Files

- .markdownlint-cli2.jsonc - Configuration for the markdownlint-cli2 tool
- .markdownlint.json - Configuration for the markdownlint VS Code extension and other tools
- .markdownlintignore - Files to ignore during linting
- .markdownlintrc - Legacy configuration for backward compatibility

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
```powershell
# Add this to your .vscode/settings.json
"markdownlint.config": {
  "extends": ".github/linting/.markdownlint.json"
}
```

## Available Scripts

- `sync-config.ps1` - Synchronizes configuration files to the root directory
- `run-markdown-lint.ps1` - Runs markdown linting with various options
- `run-lint-check.ps1` - Validates the linting configuration
- `update-spell-checker.ps1` - Updates spell checker with linting terminology

## GitHub Workflow Integration

A GitHub workflow file is available at markdown-lint.yml that will automatically run linting on all markdown files when they are changed.
'@

# VS Code tasks content
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

# GitHub workflow content
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

# Create configuration files
$configFiles = @(
    @{
        Path = "$lintingDir/.markdownlint-cli2.jsonc"
        Content = $markdownlintCli2Content
    },
    @{
        Path = "$lintingDir/.markdownlint.json"
        Content = $markdownlintJsonContent
    },
    @{
        Path = "$lintingDir/.markdownlintignore"
        Content = $markdownlintIgnoreContent
    },
    @{
        Path = "$lintingDir/.markdownlintrc"
        Content = $markdownlintrcContent
    },
    @{
        Path = "$lintingDir/sync-config.ps1"
        Content = $syncConfigContent
    },
    @{
        Path = "$lintingDir/run-markdown-lint.ps1"
        Content = $runMarkdownLintContent
    },
    @{
        Path = "$lintingDir/run-markdown-lint.sh"
        Content = $runMarkdownLintShContent
    },
    @{
        Path = "$lintingDir/run-lint-check.ps1"
        Content = $runLintCheckContent
    },
    @{
        Path = "$lintingDir/update-spell-checker.ps1"
        Content = $updateSpellCheckerContent
    },
    @{
        Path = "$lintingDir/README.md"
        Content = $readmeContent
    },
    @{
        Path = "$lintingDir/markdown-tasks.code-tasks"
        Content = $tasksContent
    },
    @{
        Path = ".github/workflows/markdown-lint.yml"
        Content = $workflowContent
    }
)

# Create each file
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

# Make shell script executable (helpful if used in Unix/Linux)
if (Test-Path "$lintingDir/run-markdown-lint.sh") {
    # This doesn't actually do anything in Windows, but it's a reminder
    # In Unix/Linux, you would use: chmod +x $lintingDir/run-markdown-lint.sh
    Write-Host "Note: If using on Unix/Linux, make sure to set execute permissions:" -ForegroundColor Yellow
    Write-Host "chmod +x $lintingDir/run-markdown-lint.sh" -ForegroundColor Yellow
}

# If CleanupRoot is specified, remove root configuration files and create redirects
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

    # Create .markdownlintrc.js redirect in root
    $redirectContent = @'
// This file redirects to the configuration in .github/linting
module.exports = require('./.github/linting/.markdownlintrc');
'@
    Set-Content -Path ".markdownlintrc.js" -Value $redirectContent
    Write-Host "Created .markdownlintrc.js redirect to .github/linting/.markdownlintrc" -ForegroundColor Green

    # Update VS Code settings to point directly to .github/linting files
    $vsCodeSettingsPath = ".vscode/settings.json"
    if (Test-Path $vsCodeSettingsPath) {
        $settings = Get-Content -Path $vsCodeSettingsPath -Raw | ConvertFrom-Json
        $settings | Add-Member -NotePropertyName "markdownlint.config" -NotePropertyValue @{ extends = ".github/linting/.markdownlint.json" } -Force
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $vsCodeSettingsPath
        Write-Host "Updated VS Code settings to use .github/linting configuration directly" -ForegroundColor Green
    }

} else {
    # Run sync-config script to ensure root files are in sync
    Write-Host "`nSynchronizing configuration files to root directory..." -ForegroundColor Cyan
    if (Test-Path "$lintingDir/sync-config.ps1") {
        & "$lintingDir/sync-config.ps1"
    } else {
        Write-Host "Error: sync-config.ps1 not found" -ForegroundColor Red
    }
}

# Update VS Code Settings
$vsCodeSettingsPath = ".vscode/settings.json"
if (Test-Path $vsCodeSettingsPath) {
    Write-Host "`nUpdating VS Code settings..." -ForegroundColor Cyan

    try {
        $settings = Get-Content -Path $vsCodeSettingsPath -Raw | ConvertFrom-Json

        # Add markdownlint configuration
        $settings | Add-Member -NotePropertyName "markdownlint.config" -NotePropertyValue @{ extends = ".github/linting/.markdownlint.json" } -Force

        # Save updated settings
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $vsCodeSettingsPath

        Write-Host "VS Code settings updated successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error updating VS Code settings: $_" -ForegroundColor Red
    }
} else {
    Write-Host "VS Code settings file not found: $vsCodeSettingsPath" -ForegroundColor Yellow
    Write-Host "Creating .vscode directory..." -ForegroundColor Yellow

    if (-not (Test-Path ".vscode")) {
        New-Item -Path ".vscode" -ItemType Directory -Force | Out-Null
    }

    # Create minimal settings file with markdownlint configuration
    $settings = @{
        "markdownlint.config" = @{
            extends = ".github/linting/.markdownlint.json"
        }
    }

    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $vsCodeSettingsPath
    Write-Host "Created new VS Code settings file with markdownlint configuration." -ForegroundColor Green
}

# Update Spell Checker
Write-Host "`nUpdating spell checker..." -ForegroundColor Cyan
if (Test-Path "$lintingDir/update-spell-checker.ps1") {
    & "$lintingDir/update-spell-checker.ps1"
} else {
    Write-Host "Error: update-spell-checker.ps1 not found" -ForegroundColor Red
}

# Validate JSON/JSONC files
Write-Host "`nValidating configuration files..." -ForegroundColor Cyan
$jsonFiles = @(
    "$lintingDir/.markdownlint-cli2.jsonc",
    "$lintingDir/.markdownlint.json",
    "$lintingDir/.markdownlintrc"
)

# Fix the JSON validation regex patterns
foreach ($file in $jsonFiles) {
    if (Test-Path $file) {
        try {
            $content = Get-Content -Path $file -Raw

            # For JSONC files, remove comments before parsing
            if ($file -like "*.jsonc") {
                # Properly escape the regex patterns with single quotes
                # Remove single-line comments
                $content = $content -replace '\/\/.*', ''
                # Remove multi-line comments with proper regex
                $content = $content -replace '(?s)\/\*.*?\*\/', ''
            }

            $null = $content | ConvertFrom-Json
            Write-Host "  ✓ $file is valid JSON" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ $file is not valid JSON: $_" -ForegroundColor Red
        }
    }
}

# Clean Up Temporary Files
Write-Host "`nChecking for orphaned files..." -ForegroundColor Cyan
$tempFiles = @(
    "temp.markdownlint-cli2.jsonc"
)

foreach ($file in $tempFiles) {
    if (Test-Path $file) {
        Write-Host "Removing orphaned file: $file" -ForegroundColor Yellow
        Remove-Item -Path $file -Force
    }
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

# Summary
Write-Host "`n=== Markdown Linting Configuration Setup Complete ===" -ForegroundColor Green
Write-Host "`nThe following components have been set up:" -ForegroundColor White
Write-Host "- Markdown linting configuration files in .github/linting"
if ($CleanupRoot) {
    Write-Host "- Root configuration files replaced with redirects to .github/linting"
} else {
    Write-Host "- Root configuration files synchronized with .github/linting"
}
Write-Host "- VS Code integration with settings and tasks"
Write-Host "- Spell checker integration with linting terminology"
Write-Host "- GitHub workflow for automated linting"

Write-Host "`nTo make .github/linting the exclusive source of truth, run:" -ForegroundColor White
Write-Host "  pwsh setup-markdown-linting.ps1 -CleanupRoot" -ForegroundColor Yellow

Write-Host "`nTo validate the configuration, run:" -ForegroundColor White
Write-Host "  pwsh .github/linting/run-lint-check.ps1" -ForegroundColor Yellow

Write-Host "`nTo run linting on GitHub markdown files:" -ForegroundColor White
Write-Host "  pwsh .github/linting/run-markdown-lint.ps1" -ForegroundColor Yellow

Write-Host "`nTo fix linting issues automatically:" -ForegroundColor White
Write-Host "  pwsh .github/linting/run-markdown-lint.ps1 -Fix" -ForegroundColor Yellow
```

The script is now complete with all the necessary sections and proper formatting. I've made sure the ending includes the full "To fix linting issues automatically" section that was previously cut off, and added proper PowerShell formatting throughout.