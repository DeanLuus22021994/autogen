# .github\linting\MarkdownLintHelpers.psm1
# Shared helper functions for markdown linting scripts

using namespace System.IO
using namespace System.Management.Automation

# Constants for file paths and content templates
$script:lintingDir = ".github/linting"
$script:workflowDir = ".github/workflows"

# cSpell:ignore esac
# Note: 'esac' is a valid bash keyword - it's 'case' spelled backwards
# and is used to end case statements in shell scripts

function Show-MarkdownLintHelp {
    [CmdletBinding()]
    param()

    Write-Host "Markdown Linting Setup Script" -ForegroundColor Cyan
    Write-Host "Parameters: -Force -Validate -CleanupRoot -Help"
    Write-Host "`nOptions:"
    Write-Host "  -Force        Overwrite existing files without prompting"
    Write-Host "  -Validate     Run validation after setup"
    Write-Host "  -CleanupRoot  Remove root config files and create redirects"
    Write-Host "  -Help         Show this help message"
}

function Get-Confirmation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $response = Read-Host "$Message (y/n)"
    return $response -eq "y"
}

function New-MarkdownLintingFiles {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    # Get configuration file templates
    $configFiles = @(
        @{
            Path = ".github/linting/.markdownlint-cli2.jsonc"
            Content = Get-MarkdownlintCli2Config
        },
        @{
            Path = ".github/linting/.markdownlint.json"
            Content = Get-MarkdownlintJsonConfig
        },
        @{
            Path = ".github/linting/.markdownlintignore"
            Content = Get-MarkdownlintIgnoreConfig
        },
        @{
            Path = ".github/linting/.markdownlintrc"
            Content = Get-MarkdownlintRcConfig
        },
        @{
            Path = ".github/linting/Sync-MarkdownConfig.ps1"
            Content = Get-SyncConfigContent
        },
        @{
            Path = ".github/linting/Invoke-MarkdownLint.ps1"
            Content = Get-RunMarkdownLintPsContent
        },
        @{
            Path = ".github/linting/Invoke-MarkdownLint.sh"
            Content = Get-RunMarkdownLintShContent
        },
        @{
            Path = ".github/linting/Test-MarkdownLinting.ps1"
            Content = Get-LintCheckContent
        },
        @{
            Path = ".github/linting/Update-SpellChecker.ps1"
            Content = Get-UpdateSpellCheckerContent
        },
        @{
            Path = ".github/linting/README.md"
            Content = Get-ReadmeContent
        },
        @{
            Path = ".github/linting/markdown-tasks.code-tasks"
            Content = Get-TasksContent
        },
        @{
            Path = ".github/workflows/markdown-lint.yml"
            Content = Get-WorkflowContent
        }
    )

    # Create each file
    foreach ($file in $configFiles) {
        # Ensure directory exists
        $directory = Split-Path -Path $file.Path -Parent
        if (-not (Test-Path $directory)) {
            try {
                $null = New-Item -Path $directory -ItemType Directory -Force -ErrorAction Stop
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
    if (Test-Path "$lintingDir/Invoke-MarkdownLint.sh") {
        Write-Host "Note: If using on Unix/Linux, run chmod +x $lintingDir/Invoke-MarkdownLint.sh" -ForegroundColor Yellow

        # Try to set permissions on Unix-like systems
        if ($IsLinux -or $IsMacOS) {
            try {
                & chmod +x "$lintingDir/Invoke-MarkdownLint.sh" 2>$null
                Write-Host "Executable permission set for Invoke-MarkdownLint.sh" -ForegroundColor Green
            }
            catch {
                Write-Host "Note: Could not set executable permissions automatically" -ForegroundColor Yellow
            }
        }
    }
}

function Invoke-MarkdownLintingCleanup {
    [CmdletBinding()]
    param()

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
    Update-VsCodeSettings
}

function Update-VsCodeSettings {
    [CmdletBinding()]
    param()

    $vsCodeSettingsPath = ".vscode/settings.json"
    if (Test-Path $vsCodeSettingsPath) {
        try {
            $settings = Get-Content -Path $vsCodeSettingsPath -Raw | ConvertFrom-Json -AsHashtable

            # Add markdownlint configuration
            $settings["markdownlint.config"] = @{
                extends = ".github/linting/.markdownlint.json"
            }

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

            $newSettings = @{
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
}

function Invoke-LintValidation {
    [CmdletBinding()]
    param()

    if (Test-Path "$lintingDir/Test-MarkdownLinting.ps1") {
        try {
            & "$lintingDir/Test-MarkdownLinting.ps1"
        }
        catch {
            Write-Host "Error during validation: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Error: Test-MarkdownLinting.ps1 not found" -ForegroundColor Red
    }
}

# Configuration content template functions
function Get-MarkdownlintCli2Config {
    return @'
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
  "customizationRules": [
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
}

function Get-MarkdownlintJsonConfig {
    return @'
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
  "customRules": {},
  "MD046": { "style": "consistent" },
  "MD048": { "style": "backtick" },
  "MD041": true,
  "MD042": true,
  "MD043": true,
  "MD044": true
}
'@
}

function Get-MarkdownlintIgnoreConfig {
    return @'
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
}

function Get-MarkdownlintRcConfig {
    return @'
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
}

function Get-SyncConfigContent {
    return @'
# .github/linting/Sync-MarkdownConfig.ps1
# Sync Markdown Linting Configuration

$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
}

# Define file pairs to sync (source and target)
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

# Create JavaScript redirect
$redirectJs = '// This file redirects to the configuration in .github/linting
module.exports = require("./.github/linting/.markdownlintrc");'

Set-Content -Path ".markdownlintrc.js" -Value $redirectJs
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
}

function Get-RunMarkdownLintPsContent {
    return @'
# .github/linting/Invoke-MarkdownLint.ps1
# Script to run markdown linting on the repository

param(
    [string]$ConfigPath = ".markdownlint-cli2.jsonc",
    [string]$TargetPath = ".github/**/*.md",
    [switch]$Fix,
    [switch]$Help
)

# Show help if requested
if ($Help) {
    Write-Host "Usage: .\Invoke-MarkdownLint.ps1 [-ConfigPath <path>] [-TargetPath <glob>] [-Fix] [-Help]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -ConfigPath <path>   Path to config file (default: .markdownlint-cli2.jsonc)"
    Write-Host "  -TargetPath <glob>   Glob pattern for files to lint (default: .github/**/*.md)"
    Write-Host "  -Fix                 Fix linting issues where possible"
    Write-Host "  -Help                Show this help message"
    Write-Host ""
    Write-Host "Related Scripts:"
    Write-Host "  .\Test-MarkdownLinting.ps1      Validate the linting configuration"
    Write-Host "  .\Sync-MarkdownConfig.ps1       Sync linting config to root directory"
    Write-Host "  .\Update-SpellChecker.ps1       Update spell checker with linting terms"
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
}

function Get-RunMarkdownLintShContent {
    return @'
#!/bin/bash
# .github/linting/Invoke-MarkdownLint.sh
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
      echo "Usage: ./Invoke-MarkdownLint.sh [--config <path>] [--target <glob>] [--fix] [--help]"
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
}

function Get-LintCheckContent {
    return @'
# .github/linting/Test-MarkdownLinting.ps1
# Lint Check Utility Script

param (
    [switch]$Fix,
    [switch]$Help
)

if ($Help) {
    Write-Host "Lint Check Utility"
    Write-Host "Usage: ./Test-MarkdownLinting.ps1 [options]"
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
    ".github/linting/Invoke-MarkdownLint.ps1",
    ".github/linting/Invoke-MarkdownLint.sh",
    ".github/linting/Sync-MarkdownConfig.ps1",
    ".github/linting/Update-SpellChecker.ps1"
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
    Write-Host "  pwsh .github/linting/Sync-MarkdownConfig.ps1" -ForegroundColor Yellow

    if ($Fix) {
        Write-Host "`nAttempting to fix sync issues..." -ForegroundColor Yellow
        & ".github/linting/Sync-MarkdownConfig.ps1"
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
            & pwsh .github/linting/Invoke-MarkdownLint.ps1 -TargetPath ".github/linting/README.md"
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
}

function Get-UpdateSpellCheckerContent {
    return @'
# .github/linting/Update-SpellChecker.ps1
# Update Spell Checker for Linting

# Use advanced PowerShell 7.5 features
using namespace System.Collections.Generic

# Navigate to repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
Set-Location ($repoRoot ?? $PWD.Path)

$settingsPath = ".vscode/settings.json"

# Use modern null-coalescing assignment to initialize
$settings = if (Test-Path $settingsPath) {
    $settingsContent = Get-Content -Path $settingsPath -Raw
    try { $settingsContent | ConvertFrom-Json -AsHashtable } catch { @{} }
} else {
    @{}
}

# Initialize words array with null coalescing
$settings['cSpell.words'] ??= @()
$existingWords = $settings['cSpell.words']

# Common linting terminology to add to dictionary
$lintingWords = @(
    "markdownlint",
    "markdownlintrc",
    "markdownlintignore",
    "markdownlintcli2"
)

# Use advanced pipeline operations to find new words
$newWords = $lintingWords.Where({ $_ -notin $existingWords })

if ($newWords.Count -gt 0) {
    Write-Host "Adding the following words to the VS Code spell checker dictionary:" -ForegroundColor Cyan
    $newWords | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }

    # Use PowerShell 7.5 pipeline enhancement for array operations
    $settings['cSpell.words'] = ($existingWords + $newWords) | Sort-Object -Unique

    # Create directory if it doesn't exist
    $settingsDir = Split-Path $settingsPath -Parent
    if (-not (Test-Path $settingsDir)) {
        New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
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

    # Use PowerShell pipeline to filter for new entries with Where-Object
    $newDictionaryEntries = $lintingWords.Where({ $_ -notin $dictionary })

    if ($newDictionaryEntries.Count -gt 0) {
        Write-Host "`nAdding words to the main dictionary file:" -ForegroundColor Cyan
        $newDictionaryEntries | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }

        # Add new words and sort the dictionary
        $newDictionaryEntries | Add-Content -Path $dictionaryPath
        Get-Content -Path $dictionaryPath | Sort-Object -Unique | Set-Content -Path $dictionaryPath

        Write-Host "Main dictionary file updated successfully!" -ForegroundColor Green
    }
}

Write-Host "Spell checker configuration update complete!" -ForegroundColor Green
'@
}

function Get-ReadmeContent {
    return @'
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
3. **Root Redirect**: The `Sync-MarkdownConfig.ps1` script maintains copies of the configuration files in the root directory

## Running Linting

Use the provided scripts:
- `Invoke-MarkdownLint.ps1` - For PowerShell environments
- `Invoke-MarkdownLint.sh` - For bash environments

## Maintaining Configuration

When updating any linting rules, make changes **only** to the files in this directory, then run:
```
pwsh Sync-MarkdownConfig.ps1
```

## Setup

If adding this to a new repository, simply run:
```
pwsh Sync-MarkdownConfig.ps1
```

To update your VS Code settings to use these configurations:
```json
// Add this to your .vscode/settings.json
"markdownlint.config": {
  "extends": ".github/linting/.markdownlint.json"
}
```

## Available Scripts

- `Sync-MarkdownConfig.ps1` - Synchronizes configuration files to the root directory
- `Invoke-MarkdownLint.ps1` - Runs markdown linting with various options
- `Test-MarkdownLinting.ps1` - Validates the linting configuration
- `Update-SpellChecker.ps1` - Updates spell checker with linting terminology
'@
}

function Get-TasksContent {
    return @'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Markdown Lint Check",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-File",
                "${workspaceFolder}/.github/linting/Invoke-MarkdownLint.ps1"
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
                "${workspaceFolder}/.github/linting/Invoke-MarkdownLint.ps1",
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
                "${workspaceFolder}/.github/linting/Test-MarkdownLinting.ps1"
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
}

function Get-WorkflowContent {
    return @'
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
        run: markdownlint-cli2 .github/**/*.md --config .github/linting/.markdownlint-cli2.jsonc

      - name: Run lint check on documentation
        run: markdownlint-cli2 docs/**/*.md --config .github/linting/.markdownlint-cli2.jsonc
        continue-on-error: true

      - name: Run lint check on root markdown files
        run: markdownlint-cli2 *.md --config .github/linting/.markdownlint-cli2.jsonc
'@
}
