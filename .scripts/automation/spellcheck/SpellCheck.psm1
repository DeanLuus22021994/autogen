# SpellCheck.psm1
# Provides spell checking functionality for the AutoGen project

#Requires -Version 7.0

# Import dependencies
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Join-Path (Split-Path -Parent (Split-Path -Parent $scriptPath)) "github"
Import-Module "$rootPath\Common.psm1" -Force

# Default paths
$defaultDictionaryPath = ".config/cspell-dictionary.txt"
$defaultSettingsPath = ".vscode/settings.json"
$defaultDocsPath = "docs"

# Technical terms to include in dictionary
$technicalTerms = @(
    # Development tools and frameworks
    "docfx",
    "vscode",
    "pylance",
    # Technical terms
    "agenthost",
    "appsettings",
    "websocket",
    "Akka",
    "Gatewway",
    "perameters",
    "davidanson",
    "iclude",
    "powershell",
    "pwsh",
    # Microsoft terms
    "Micrososft",
    "MEAI",
    "azureml",
    # Common misspellings found in the codebase
    "additonal",
    "heirarchy"
)

function Invoke-SpellCheckOnWorkspace {
    <#
    .SYNOPSIS
        Runs spell check on the entire workspace.
    .DESCRIPTION
        Executes CSpell on all relevant files in the workspace.
    .PARAMETER Verbose
        Show detailed output.
    .EXAMPLE
        Invoke-SpellCheckOnWorkspace -Verbose
    #>
    [CmdletBinding()]
    param()

    try {
        Write-SectionHeader "Workspace Spell Check"

        # Check if npx/cspell is available
        $cspellPath = Get-Command "npx" -ErrorAction SilentlyContinue
        if (-not $cspellPath) {
            Write-StatusMessage "CSpell not found. Please install Node.js and CSpell." "Error" 0
            return
        }

        # Run cspell on the workspace
        Write-StatusMessage "Running spell check on workspace..." "Info" 0
        $result = npx cspell "**/*.{md,ps1,py,js,ts,cs,json,ipynb}" --no-progress

        Write-StatusMessage "Spell check complete!" "Success" 0
    }
    catch {
        Write-StatusMessage "An error occurred: $_" "Error" 0
    }
}

function Invoke-SpellCheckOnPath {
    <#
    .SYNOPSIS
        Runs spell check on a specific path.
    .DESCRIPTION
        Executes CSpell on files in the specified path.
    .PARAMETER Path
        The path to check.
    .PARAMETER Verbose
        Show detailed output.
    .EXAMPLE
        Invoke-SpellCheckOnPath -Path "docs" -Verbose
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    try {
        Write-SectionHeader "Spell Check on $Path"

        # Check if path exists
        if (-not (Test-Path $Path)) {
            Write-StatusMessage "Path not found: $Path" "Error" 0
            return
        }

        # Check if npx/cspell is available
        $cspellPath = Get-Command "npx" -ErrorAction SilentlyContinue
        if (-not $cspellPath) {
            Write-StatusMessage "CSpell not found. Please install Node.js and CSpell." "Error" 0
            return
        }

        # Run cspell on the specified path
        Write-StatusMessage "Running spell check on $Path..." "Info" 0
        $result = npx cspell "$Path/**/*.{md,ps1,py,js,ts,cs,json,ipynb}" --no-progress

        Write-StatusMessage "Spell check complete!" "Success" 0
    }
    catch {
        Write-StatusMessage "An error occurred: $_" "Error" 0
    }
}

function Update-SpellCheckDictionary {
    <#
    .SYNOPSIS
        Updates the custom spell check dictionary.
    .DESCRIPTION
        Adds technical terms to the custom dictionary and updates VS Code settings.
    .PARAMETER DictionaryPath
        Path to the custom dictionary file.
    .PARAMETER Verbose
        Show detailed output.
    .EXAMPLE
        Update-SpellCheckDictionary -Verbose
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$DictionaryPath = $defaultDictionaryPath
    )

    try {
        Write-SectionHeader "Dictionary Update"

        # Ensure dictionary file exists
        if (-not (Test-Path $DictionaryPath)) {
            Write-StatusMessage "Dictionary file not found. Creating new dictionary file at $DictionaryPath" "Info" 0
            New-Item -Path $DictionaryPath -ItemType File -Force | Out-Null
            Add-Content -Path $DictionaryPath -Value "# AutoGen Custom Dictionary`n# Add technical terms, abbreviations, and custom words here`n"
        }

        # Read existing dictionary
        $dictionaryContent = Get-Content -Path $DictionaryPath -Raw
        $termsAdded = 0

        # Add technical terms if they don't exist
        foreach ($term in $technicalTerms) {
            if (-not ($dictionaryContent -match "\b$term\b")) {
                Add-Content -Path $DictionaryPath -Value $term
                $termsAdded++
                Write-StatusMessage "Added term: $term" "Info" 1
            }
        }

        if ($termsAdded -gt 0) {
            Write-StatusMessage "Added $termsAdded new terms to the dictionary." "Success" 0
        } else {
            Write-StatusMessage "No new terms were added to the dictionary." "Info" 0
        }

        # Sort dictionary entries alphabetically (excluding comments)
        $dictionaryLines = Get-Content -Path $DictionaryPath
        $comments = $dictionaryLines | Where-Object { $_ -match "^#" }
        $terms = $dictionaryLines | Where-Object { $_ -notmatch "^#" -and $_ -match "\S" } | Sort-Object

        $sortedDictionary = $comments + $terms
        Set-Content -Path $DictionaryPath -Value $sortedDictionary

        Write-StatusMessage "Dictionary has been sorted alphabetically." "Success" 0
    }
    catch {
        Write-StatusMessage "An error occurred: $_" "Error" 0
    }
}

function Sync-SpellCheckConfiguration {
    <#
    .SYNOPSIS
        Synchronizes the spell check configuration with VS Code settings.
    .DESCRIPTION
        Updates VS Code settings to use the custom dictionary.
    .PARAMETER DictionaryPath
        Path to the custom dictionary file.
    .PARAMETER SettingsPath
        Path to the VS Code settings file.
    .PARAMETER Verbose
        Show detailed output.
    .EXAMPLE
        Sync-SpellCheckConfiguration -Verbose
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$DictionaryPath = $defaultDictionaryPath,

        [Parameter(Mandatory=$false)]
        [string]$SettingsPath = $defaultSettingsPath
    )

    try {
        Write-SectionHeader "Spell Check Configuration Sync"

        # Ensure settings file exists
        if (-not (Test-Path $SettingsPath)) {
            Write-StatusMessage "VS Code settings file not found at $SettingsPath" "Error" 0
            return
        }

        # Read VS Code settings
        $settingsContent = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json -AsHashtable

        # Update dictionary configuration
        if (-not $settingsContent.ContainsKey("cSpell.customDictionaries")) {
            $settingsContent["cSpell.customDictionaries"] = @{
                "autogen-dictionary" = @{
                    "name" = "AutoGen Custom Dictionary"
                    "path" = "`${workspaceFolder}/$DictionaryPath"
                    "description" = "Custom dictionary for AutoGen project terms"
                    "addWords" = $true
                }
                "project-words" = $true
            }

            Write-StatusMessage "Added custom dictionary configuration" "Info" 0
        }

        # Update dictionary definitions
        if (-not $settingsContent.ContainsKey("cSpell.dictionaryDefinitions")) {
            $settingsContent["cSpell.dictionaryDefinitions"] = @(
                @{
                    "name" = "autogen-dictionary"
                    "path" = "`${workspaceFolder}/$DictionaryPath"
                }
            )

            Write-StatusMessage "Added dictionary definition" "Info" 0
        }

        # Write updated settings
        $settingsContent | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsPath

        Write-StatusMessage "VS Code settings updated successfully!" "Success" 0
    }
    catch {
        Write-StatusMessage "An error occurred: $_" "Error" 0
    }
}

function Get-SpellCheckStatus {
    <#
    .SYNOPSIS
        Gets the status of spell check configuration.
    .DESCRIPTION
        Checks if spell check is properly configured in the workspace.
    .PARAMETER Verbose
        Show detailed output.
    .EXAMPLE
        Get-SpellCheckStatus -Verbose
    #>
    [CmdletBinding()]
    param()

    try {
        Write-SectionHeader "Spell Check Status"

        $dictionaryExists = Test-Path $defaultDictionaryPath
        $settingsExist = Test-Path $defaultSettingsPath

        Write-StatusMessage "Dictionary file: $(if ($dictionaryExists) { "✅ Exists" } else { "❌ Missing" })" "Info" 0
        Write-StatusMessage "VS Code settings: $(if ($settingsExist) { "✅ Exists" } else { "❌ Missing" })" "Info" 0

        if ($settingsExist) {
            $settingsContent = Get-Content -Path $defaultSettingsPath -Raw | ConvertFrom-Json -AsHashtable
            $hasDictionaryConfig = $settingsContent.ContainsKey("cSpell.customDictionaries")

            Write-StatusMessage "Dictionary configuration: $(if ($hasDictionaryConfig) { "✅ Configured" } else { "❌ Not configured" })" "Info" 0
        }

        if ($dictionaryExists) {
            $wordCount = (Get-Content -Path $defaultDictionaryPath | Where-Object { $_ -notmatch "^#" -and $_ -match "\S" }).Count
            Write-StatusMessage "Dictionary contains $wordCount words" "Info" 0
        }
    }
    catch {
        Write-StatusMessage "An error occurred: $_" "Error" 0
    }
}

# Export module functions
Export-ModuleMember -Function Invoke-SpellCheckOnWorkspace
Export-ModuleMember -Function Invoke-SpellCheckOnPath
Export-ModuleMember -Function Update-SpellCheckDictionary
Export-ModuleMember -Function Sync-SpellCheckConfiguration
Export-ModuleMember -Function Get-SpellCheckStatus
