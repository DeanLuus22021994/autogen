# Update-SpellCheck.ps1
# Updates the custom spell-checking dictionary and runs a spell check on documentation

#Requires -Version 7.0

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent (Split-Path -Parent $scriptPath)
$modulesPath = Join-Path $rootPath "github"

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
        [switch]$RunSpellCheck,

        [Parameter()]
        [switch]$Synchronize
    )

    Write-Host ""
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

                    # Synchronize dictionary with VS Code settings
                    if ($Synchronize) {
                        Update-VsCodeDictionarySettings -DictionaryPath $DictionaryPath
                    }
                }
            }
        }
    }
    else {
        Write-StatusMessage "Spell check skipped. Use -RunSpellCheck to perform spell check." "Info" 0
    }

    # Synchronize with VS Code settings if requested
    if ($Synchronize) {
        Update-VsCodeDictionarySettings -DictionaryPath $DictionaryPath
    }

    Write-StatusMessage "Spell check dictionary update complete" "Success" 0
}

function Update-VsCodeDictionarySettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$DictionaryPath
    )

    Write-StatusMessage "Updating VS Code settings for dictionary integration..." "Info" 0

    # Update VS Code settings to use the dictionary
    $settingsPath = ".vscode/settings.json"
    if (Test-Path $settingsPath) {
        try {
            $settingsContent = Get-Content $settingsPath -Raw
            $settings = ConvertFrom-Json $settingsContent -AsHashtable -ErrorAction Stop
        }
        catch {
            Write-StatusMessage "Failed to parse VS Code settings. Using default empty object." "Warning" 0
            $settings = @{}
        }

        # Ensure cSpell.words array exists
        if (-not $settings.ContainsKey("cSpell.words")) {
            $settings["cSpell.words"] = @()
        }

        # Ensure customDictionaries section exists
        if (-not $settings.ContainsKey("cSpell.customDictionaries")) {
            $settings["cSpell.customDictionaries"] = @{
                "custom-dictionary" = @{
                    "path" = '${workspaceRoot}/' + $DictionaryPath
                    "addWords" = $true
                    "scope" = "workspace"
                }
            }

            # Convert back to JSON with proper formatting
            $settingsJson = ConvertTo-Json $settings -Depth 10

            # Prevent Write-Output from writing to output
            $null = Set-Content -Path $settingsPath -Value $settingsJson

            Write-StatusMessage "Updated VS Code settings to use custom dictionary" "Success" 0
        }

        # Add words from dictionary to cSpell.words if they're not already there
        if (Test-Path $DictionaryPath) {
            $dictionaryWords = Get-Content $DictionaryPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith("#") }

            $wordList = [System.Collections.ArrayList]($settings["cSpell.words"])
            $updatedCount = 0

            foreach ($word in $dictionaryWords) {
                if (-not $wordList.Contains($word)) {
                    $wordList.Add($word) | Out-Null
                    $updatedCount++
                }
            }

            if ($updatedCount -gt 0) {
                $settings["cSpell.words"] = $wordList

                # Convert back to JSON with proper formatting
                $settingsJson = ConvertTo-Json $settings -Depth 10

                # Prevent Set-Content from writing to output
                $null = Set-Content -Path $settingsPath -Value $settingsJson

                Write-StatusMessage "Added $updatedCount words to VS Code spell checker" "Success" 0
            }
            else {
                Write-StatusMessage "All dictionary words already in VS Code settings" "Info" 0
            }
        }
    }
    else {
        Write-StatusMessage "VS Code settings file not found at: $settingsPath" "Warning" 0

        # Create minimal settings file with dictionary configuration
        $settings = @{
            "cSpell.customDictionaries" = @{
                "custom-dictionary" = @{
                    "path" = '${workspaceRoot}/' + $DictionaryPath
                    "addWords" = $true
                    "scope" = "workspace"
                }
            }
            "cSpell.words" = @()
        }

        # Convert to JSON with proper formatting
        $settingsJson = ConvertTo-Json $settings -Depth 10

        # Create the .vscode directory if it doesn't exist
        $vscodePath = Split-Path -Parent $settingsPath
        if (-not (Test-Path $vscodePath)) {
            New-Item -Path $vscodePath -ItemType Directory -Force | Out-Null
        }

        # Create the settings file
        New-Item -Path $settingsPath -ItemType File -Force | Out-Null
        Set-Content -Path $settingsPath -Value $settingsJson

        Write-StatusMessage "Created new VS Code settings file with dictionary configuration" "Success" 0
    }
}

function Merge-DictionaryFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$PrimaryDictionaryPath,

        [Parameter(Mandatory=$true)]
        [string[]]$SecondaryDictionaryPaths,

        [Parameter()]
        [switch]$Overwrite
    )

    Write-SectionHeader "Dictionary Files Merge"

    # Ensure primary dictionary exists
    if (-not (Test-Path $PrimaryDictionaryPath)) {
        Write-StatusMessage "Primary dictionary not found at: $PrimaryDictionaryPath" "Error" 0
        return $false
    }

    # Read primary dictionary
    $primaryWords = Get-Content $PrimaryDictionaryPath |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith("#") }

    $mergedWords = [System.Collections.ArrayList]::new($primaryWords)
    $addedCount = 0

    # Process each secondary dictionary
    foreach ($secondaryPath in $SecondaryDictionaryPaths) {
        if (Test-Path $secondaryPath) {
            Write-StatusMessage "Processing secondary dictionary: $secondaryPath" "Info" 0

            $secondaryWords = Get-Content $secondaryPath |
                             Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith("#") }

            foreach ($word in $secondaryWords) {
                if (-not $mergedWords.Contains($word)) {
                    $mergedWords.Add($word) | Out-Null
                    $addedCount++
                }
            }
        }
        else {
            Write-StatusMessage "Secondary dictionary not found at: $secondaryPath" "Warning" 0
        }
    }

    # If words were added, update the primary dictionary
    if ($addedCount -gt 0) {
        if ($Overwrite) {
            # Create header for the new merged dictionary
            $newDictionary = @"
# Merged Dictionary File
# Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# Contains words from:
# - $PrimaryDictionaryPath
$(foreach ($path in $SecondaryDictionaryPaths) { "# - $path" })

"@

            # Add all words
            foreach ($word in $mergedWords) {
                $newDictionary += "$word`n"
            }

            # Save the merged dictionary
            Set-Content -Path $PrimaryDictionaryPath -Value $newDictionary

            Write-StatusMessage "Added $addedCount words to primary dictionary" "Success" 0
            Write-StatusMessage "Updated primary dictionary at: $PrimaryDictionaryPath" "Success" 0
        }
        else {
            # Get the current content to preserve comments and structure
            $currentContent = Get-Content $PrimaryDictionaryPath -Raw

            # Add a new section for merged words
            $newSection = @"

# Merged from secondary dictionaries on $(Get-Date -Format "yyyy-MM-dd")
$(foreach ($word in ($mergedWords | Where-Object { -not $primaryWords.Contains($_) })) { "$word" })
"@

            # Append the new section
            $updatedContent = $currentContent + $newSection
            Set-Content -Path $PrimaryDictionaryPath -Value $updatedContent

            Write-StatusMessage "Added $addedCount words to primary dictionary" "Success" 0
            Write-StatusMessage "Updated primary dictionary at: $PrimaryDictionaryPath" "Success" 0
        }

        return $true
    }
    else {
        Write-StatusMessage "No new words to add to the primary dictionary" "Info" 0
        return $false
    }
}

# Export the functions
Export-ModuleMember -Function Update-SpellCheckDictionary, Update-VsCodeDictionarySettings, Merge-DictionaryFiles
