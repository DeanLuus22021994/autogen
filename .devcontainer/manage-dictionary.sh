#!/bin/bash
# manage-dictionary.sh
# Manages the custom dictionary for spell checking

# Function to display usage
function show_usage {
    echo "Usage: $0 [command]"
    echo "Commands:"
    echo "  add-words     Add words to the custom dictionary"
    echo "  sync          Synchronize dictionary with IDE settings"
    echo "  status        Show current dictionary status"
    exit 1
}

# Determine correct PowerShell command
PWSH_CMD="pwsh"
if ! command -v pwsh &> /dev/null; then
    if command -v powershell &> /dev/null; then
        PWSH_CMD="powershell"
    else
        echo "ERROR: PowerShell not found. Please install PowerShell."
        exit 1
    fi
fi

# Check if a command was provided
if [ $# -eq 0 ]; then
    show_usage
fi

# Process command
case $1 in
    add-words)
        echo "Adding words to dictionary..."
        $PWSH_CMD -File ".scripts/automation/spellcheck/Invoke-SpellCheck.ps1" -Action Update -Verbose
        ;;
    sync)
        echo "Synchronizing dictionary with IDE settings..."
        $PWSH_CMD -File ".scripts/automation/spellcheck/Invoke-SpellCheck.ps1" -Action Sync -Verbose
        ;;
    status)
        echo "Checking dictionary status..."
        $PWSH_CMD -Command "Import-Module '.scripts/automation/spellcheck/SpellCheck.psm1' -Force; Get-SpellCheckStatus -Verbose"
        ;;
    *)
        echo "Unknown command: $1"
        show_usage
        ;;
esac