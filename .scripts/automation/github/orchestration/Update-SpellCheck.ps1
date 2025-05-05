# Update-SpellCheck.ps1
# Updates the custom spell-checking dictionary and runs a spell check on documentation

#Requires -Version 7.0

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
$modulesPath = $rootPath

# Import all modules
Import-Module "$modulesPath\Common.psm1" -Force

function Update-SpellCheckDictionary {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$DictionaryPath = ".vscode/cspell-custom-dictionary.txt",

        [Parameter()]
        [string]$DocumentationPath = "docs",

        [Parameter()]
        [switch]$RunSpellCheck
    )

    Write-SectionHeader "Spell Check Dictionary Update"

    # Ensure dictionary file exists
    if (-not (Test-Path $DictionaryPath)) {
        Write-StatusMessage "Dictionary file not found. Creating new dictionary file." "Warning" 0

        $defaultDictContent = @"
# Additional words for spell checking
# Words in this file will be recognized as correctly spelled

# Technical terms
docfx
pwsh
pylance
gitignore
agenthost
appsettings
ruff
Akka
Gatewway
perameters
davidanson
iclude
markdownlint
notmatch

# Company and product names
Micrososft
MEAI

# Spelling variants & international words
additonal
heirarchy
"@

        New-Item -Path $DictionaryPath -ItemType File -Force | Out-Null
        Set-Content -Path $DictionaryPath -Value $defaultDictContent
        Write-StatusMessage "Created dictionary file at: $DictionaryPath" "Success" 1
    }

    # Check if cspell tool is installed
    $cspellInstalled = $null
    try {
        $cspellInstalled = Get-Command npx -ErrorAction SilentlyContinue
    }
    catch {
        $cspellInstalled = $null
    }

    if (-not $cspellInstalled) {
        Write-StatusMessage "npx not found. Please install Node.js to use cspell." "Warning" 0
        Write-StatusMessage "Skipping spell check operation." "Warning" 0
        return
    }

    # Run spell check if requested
    if ($RunSpellCheck) {
        Write-StatusMessage "Running spell check on documentation..." "Info" 0

        try {
            # Run cspell on documentation
            $result = npx cspell "$DocumentationPath/**/*.md" --config .vscode/cspell.json
            Write-StatusMessage "Spell check completed successfully" "Success" 0
        }
        catch {
            Write-StatusMessage "Spell check encountered issues" "Warning" 0
            Write-StatusMessage "Consider adding unknown words to the dictionary" "Info" 1

            # Get all unknown words
            $unknownWords = @()
            $output = npx cspell "$DocumentationPath/**/*.md" --config .vscode/cspell.json --no-progress 2>&1

            foreach ($line in $output) {
                if ($line -match "Unknown word \(([^)]+)\)") {
                    $word = $Matches[1]
                    if ($unknownWords -notcontains $word) {
                        $unknownWords += $word
                    }
                }
            }

            if ($unknownWords.Count -gt 0) {
                Write-StatusMessage "Unknown words found:" "Info" 0
                foreach ($word in $unknownWords) {
                    Write-StatusMessage "  $word" "Info" 1
                }

                $addWords = Read-Host "Would you like to add these words to the dictionary? (Y/N)"
                if ($addWords -eq "Y" -or $addWords -eq "y") {
                    # Get current dictionary content
                    $dictionaryContent = Get-Content $DictionaryPath -Raw

                    # Add new section for detected words
                    $newWords = "`n# Detected words`n"
                    foreach ($word in $unknownWords) {
                        $newWords += "$word`n"
                    }

                    # Update dictionary
                    $dictionaryContent += $newWords
                    Set-Content -Path $DictionaryPath -Value $dictionaryContent

                    Write-StatusMessage "Added ${unknownWords.Count} words to dictionary" "Success" 0
                    Write-StatusMessage "Dictionary updated at: $DictionaryPath" "Success" 0
                }
            }
        }
    }
    else {
        Write-StatusMessage "Spell check skipped. Use -RunSpellCheck to perform spell check." "Info" 0
    }

    # Update VS Code settings to use the dictionary
    $settingsPath = ".vscode/settings.json"
    if (Test-Path $settingsPath) {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable

        # Ensure customDictionaries section exists
        if (-not $settings.ContainsKey("cSpell.customDictionaries")) {
            $settings["cSpell.customDictionaries"] = @{
                "custom-dictionary" = @{
                    "path" = '${workspaceRoot}/' + $DictionaryPath
                    "addWords" = $true
                    "scope" = "workspace"
                }
            }

            # Convert back to JSON and save
            $settingsJson = $settings | ConvertTo-Json -Depth 10
            Set-Content -Path $settingsPath -Value $settingsJson

            Write-StatusMessage "Updated VS Code settings to use custom dictionary" "Success" 0
        }
        else {
            Write-StatusMessage "VS Code settings already configured for custom dictionary" "Info" 0
        }
    }

    Write-StatusMessage "Spell check dictionary update complete" "Success" 0
}

# Run the update
Update-SpellCheckDictionary -RunSpellCheck
