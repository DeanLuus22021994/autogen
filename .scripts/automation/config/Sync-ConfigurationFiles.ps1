# Sync-ConfigurationFiles.ps1
# A utility script that keeps various configuration files synchronized and updated

#Requires -Version 7.0

# Set strict mode to catch more potential issues
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = (Split-Path -Parent $scriptPath)
$rootPath = (Split-Path -Parent $rootPath)
$modulesPath = Join-Path $rootPath ".scripts\automation\github"
$spellCheckPath = Join-Path $rootPath ".scripts\automation\spellcheck"

# Import core modules if they exist
if (Test-Path "$modulesPath\Common.psm1") {
    Import-Module "$modulesPath\Common.psm1" -Force
}

# Import spell check module if it exists
if (Test-Path "$spellCheckPath\SpellCheck.psm1") {
    Import-Module "$spellCheckPath\SpellCheck.psm1" -Force
}

function Write-TaskInfo {
    param (
        [string]$Message,
        [string]$Status = "Info"
    )

    # Use the function from Common.psm1 if available
    $statusFunction = Get-Command -Name "Write-StatusMessage" -ErrorAction SilentlyContinue

    if ($statusFunction) {
        Write-StatusMessage $Message $Status 0
    }
    else {
        # Fallback formatting
        $color = switch ($Status) {
            "Info" { "Cyan" }
            "Warning" { "Yellow" }
            "Error" { "Red" }
            "Success" { "Green" }
            default { "White" }
        }

        Write-Host "[$Status] $Message" -ForegroundColor $color
    }
}

function Sync-DictionaryFiles {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$PrimaryDictionaryPath = ".vscode/cspell-custom-dictionary.txt",

        [Parameter()]
        [string[]]$SecondaryDictionaryPaths = @(".config/host/dictionary_additions.txt"),

        [Parameter()]
        [switch]$UpdateVsCodeSettings,

        [Parameter()]
        [switch]$CreateDefaultDictionary
    )

    Write-TaskInfo "Starting dictionary synchronization" "Info"

    # Create default dictionary if it doesn't exist and creation is requested
    if ($CreateDefaultDictionary -and -not (Test-Path $PrimaryDictionaryPath)) {
        Write-TaskInfo "Creating default dictionary at: $PrimaryDictionaryPath" "Info"

        $defaultDictContent = @"
# AutoGen Custom Dictionary
# Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# This file contains custom words for spell checking

# Technical terms
pwsh
pylance
autogen
agentchat
asyncio
HUGGINGFACE
appdir
ruff
docfx
markdownlint
notmatch

# People and companies
Micrososft
MEAI

# Project-specific terms
Multimodal
Magentic
autogenstudio
publickey
"@

        # Create directory if needed
        $dictDir = Split-Path -Parent $PrimaryDictionaryPath
        if (-not (Test-Path $dictDir)) {
            New-Item -Path $dictDir -ItemType Directory -Force | Out-Null
        }

        # Create the file
        Set-Content -Path $PrimaryDictionaryPath -Value $defaultDictContent
        Write-TaskInfo "Created default dictionary" "Success"
    }

    # Sync with all secondary dictionaries
    foreach ($secondaryPath in $SecondaryDictionaryPaths) {
        if (Test-Path $secondaryPath) {
            Write-TaskInfo "Syncing dictionary from: $secondaryPath" "Info"

            # Try to use the module function if available
            $mergeFunction = Get-Command -Name "Merge-DictionaryFiles" -ErrorAction SilentlyContinue

            if ($mergeFunction) {
                Merge-DictionaryFiles -PrimaryDictionaryPath $PrimaryDictionaryPath -SecondaryDictionaryPaths @($secondaryPath)
            }
            else {
                # Fallback implementation
                Write-TaskInfo "Using fallback dictionary merging" "Warning"

                # Ensure primary dictionary exists
                if (-not (Test-Path $PrimaryDictionaryPath)) {
                    Write-TaskInfo "Primary dictionary not found: $PrimaryDictionaryPath" "Error"
                    continue
                }

                # Read dictionaries
                $primaryWords = Get-Content $PrimaryDictionaryPath |
                                Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith("#") }
                $secondaryWords = Get-Content $secondaryPath |
                                 Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith("#") }

                # Find words to add
                $newWords = $secondaryWords | Where-Object { $primaryWords -notcontains $_ }

                # Add new words if any found
                if ($newWords.Count -gt 0) {
                    $newWordsSection = @"

# Merged from $secondaryPath on $(Get-Date -Format "yyyy-MM-dd")
$($newWords -join "`n")
"@
                    Add-Content -Path $PrimaryDictionaryPath -Value $newWordsSection
                    Write-TaskInfo "Added $($newWords.Count) words from $secondaryPath" "Success"
                }
                else {
                    Write-TaskInfo "No new words to add from $secondaryPath" "Info"
                }
            }
        }
        else {
            Write-TaskInfo "Secondary dictionary not found: $secondaryPath" "Warning"
        }
    }

    # Update VS Code settings if requested
    if ($UpdateVsCodeSettings) {
        Write-TaskInfo "Updating VS Code settings with dictionary information" "Info"

        # Try to use the module function if available
        $updateFunction = Get-Command -Name "Update-VsCodeDictionarySettings" -ErrorAction SilentlyContinue

        if ($updateFunction) {
            Update-VsCodeDictionarySettings -DictionaryPath $PrimaryDictionaryPath
        }
        else {
            # Fallback implementation
            Write-TaskInfo "Using fallback VS Code settings update" "Warning"

            $settingsPath = ".vscode/settings.json"
            if (Test-Path $settingsPath) {
                try {
                    $settingsContent = Get-Content $settingsPath -Raw
                    $settings = ConvertFrom-Json $settingsContent -AsHashtable -ErrorAction Stop
                }
                catch {
                    Write-TaskInfo "Failed to parse VS Code settings" "Error"
                    return
                }

                # Ensure cSpell.customDictionaries section exists
                if (-not $settings.ContainsKey("cSpell.customDictionaries")) {
                    $settings["cSpell.customDictionaries"] = @{
                        "custom-dictionary" = @{
                            "path" = '${workspaceRoot}/' + $PrimaryDictionaryPath
                            "addWords" = $true
                            "scope" = "workspace"
                        }
                    }

                    # Convert to JSON and save
                    $settingsJson = ConvertTo-Json $settings -Depth 10
                    Set-Content -Path $settingsPath -Value $settingsJson

                    Write-TaskInfo "Added dictionary configuration to VS Code settings" "Success"
                }
                else {
                    Write-TaskInfo "Dictionary configuration already exists in VS Code settings" "Info"
                }
            }
            else {
                Write-TaskInfo "VS Code settings file not found: $settingsPath" "Warning"
            }
        }
    }

    Write-TaskInfo "Dictionary synchronization complete" "Success"
}

function Sync-ConfigFiles {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$IncludeDictionary,

        [Parameter()]
        [switch]$Force
    )

    Write-TaskInfo "Starting configuration file synchronization" "Info"

    # Basic checks
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $repoRoot) {
        Write-TaskInfo "Not in a git repository" "Error"
        return
    }

    # Ensure config directories exist
    $configDirs = @(
        ".config/devcontainer",
        ".config/github-runner",
        ".config/host"
    )

    foreach ($dir in $configDirs) {
        if (-not (Test-Path $dir)) {
            Write-TaskInfo "Creating directory: $dir" "Info"
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            # Add a tag file to track the directory
            $tagFile = Join-Path $dir "DIR.TAG"
            if (-not (Test-Path $tagFile)) {
                Set-Content -Path $tagFile -Value "#TODO"
            }
        }
    }    # Sync dictionary files if requested
    if ($IncludeDictionary) {
        Sync-DictionaryFiles -CreateDefaultDictionary -UpdateVsCodeSettings

        # Also sync the new spell check configurations
        $spellCheckSettings = @{
            SpellCheck = @{
                DictionaryPath = ".config/cspell-dictionary.txt"
            }
            Documentation = @{
                Path = "docs"
            }
        }
        Sync-SpellCheckConfigurations -Settings $spellCheckSettings
    }

    Write-TaskInfo "Configuration file synchronization complete" "Success"
}

function Sync-SpellCheckConfigurations {
    <#
    .SYNOPSIS
        Synchronizes spell checking configurations across the repository.
    .DESCRIPTION
        Updates the custom dictionary, settings file, and ensures consistency.
    .PARAMETER Settings
        Configuration settings for the synchronization.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]$Settings
    )

    $defaultDictionaryPath = ".config/cspell-dictionary.txt"
    $customDictionaryPath = $Settings.SpellCheck.DictionaryPath -or $defaultDictionaryPath
    $docsPath = $Settings.Documentation.Path -or "docs"

    Write-TaskInfo "Synchronizing spell check configurations..." "Info"

    # Update the dictionary with standard terms
    Update-SpellCheckDictionary -DictionaryPath $customDictionaryPath
    Write-TaskInfo "Updated custom spell check dictionary." "Success"

    # Sync with VS Code settings
    Sync-SpellCheckConfiguration -DictionaryPath $customDictionaryPath
    Write-TaskInfo "Synchronized VS Code spell check settings." "Success"

    # Create shell scripts if they don't exist
    $devContainerPath = ".devcontainer"
    $spellCheckShellPath = Join-Path $devContainerPath "spell-check.sh"
    $dictionaryManagerPath = Join-Path $devContainerPath "manage-dictionary.sh"

    if (-not (Test-Path $spellCheckShellPath) -or -not (Test-Path $dictionaryManagerPath)) {
        Write-TaskInfo "Ensuring shell scripts exist..." "Info"

        # Use the files we've already created
        chmod +x $spellCheckShellPath
        chmod +x $dictionaryManagerPath
        Write-TaskInfo "Made shell scripts executable." "Success"
    }
}

# If script is run directly (not imported as a module)
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    # Parse command line arguments
    param (
        [switch]$SyncDictionary,
        [switch]$SyncAll,
        [switch]$Force,
        [switch]$Help
    )

    # Show help if requested
    if ($Help) {
        Write-Host "Configuration File Synchronization Utility"
        Write-Host "Usage: ./Sync-ConfigurationFiles.ps1 [options]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -SyncDictionary       Synchronize dictionary files"
        Write-Host "  -SyncAll              Synchronize all configuration files"
        Write-Host "  -Force                Force updates even when files exist"
        Write-Host "  -Help                 Show this help message"
        exit 0
    }

    # Run the appropriate sync operation
    if ($SyncAll) {
        Sync-ConfigFiles -IncludeDictionary -Force:$Force
    }
    elseif ($SyncDictionary) {
        Sync-DictionaryFiles -CreateDefaultDictionary -UpdateVsCodeSettings
    }
    else {
        # Default operation
        Sync-ConfigFiles -Force:$Force
    }
}
