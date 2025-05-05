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
