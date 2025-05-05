# Invoke-SpellCheck.ps1
# Frontend script for running the spell check utility

#Requires -Version 7.0

# Get the directory of this script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "SpellCheck.psm1"

# Import the SpellCheck module
Import-Module $modulePath -Force

# Parse command line arguments
param (
    [switch]$RunSpellCheck,
    [switch]$Synchronize,
    [string]$DictionaryPath = ".vscode/cspell-custom-dictionary.txt",
    [string]$DocumentationPath = "docs",
    [switch]$MergeDictionaries,
    [string[]]$SecondaryDictionaries = @(".config/host/dictionary_additions.txt"),
    [switch]$Help
)

# Show help if requested
if ($Help) {
    Write-Host "Spell Check Utility"
    Write-Host "Usage: ./Invoke-SpellCheck.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -RunSpellCheck             Run the spell checker on documentation"
    Write-Host "  -Synchronize               Update VS Code settings with dictionary words"
    Write-Host "  -DictionaryPath <path>     Path to the main dictionary file (default: .vscode/cspell-custom-dictionary.txt)"
    Write-Host "  -DocumentationPath <path>  Path to the documentation directory (default: docs)"
    Write-Host "  -MergeDictionaries         Merge secondary dictionaries into the main dictionary"
    Write-Host "  -SecondaryDictionaries     Array of paths to secondary dictionaries"
    Write-Host "  -Help                      Show this help message"
    exit 0
}

# Main functionality
if ($MergeDictionaries) {
    Merge-DictionaryFiles -PrimaryDictionaryPath $DictionaryPath -SecondaryDictionaryPaths $SecondaryDictionaries
}
else {
    Update-SpellCheckDictionary -DictionaryPath $DictionaryPath -DocumentationPath $DocumentationPath -RunSpellCheck:$RunSpellCheck -Synchronize:$Synchronize
}
