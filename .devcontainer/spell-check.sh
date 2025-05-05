#!/bin/bash
# spell-check.sh
# Runs spell check operations for the AutoGen project

# Default settings
VERBOSE=false
FIX=false
PATH_TO_CHECK=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --fix)
      FIX=true
      shift
      ;;
    --path)
      PATH_TO_CHECK="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

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

# Set verbosity flag
VERBOSE_FLAG=""
if [ "$VERBOSE" = true ]; then
    VERBOSE_FLAG="-Verbose"
fi

# Set action based on parameters
ACTION="Check"
if [ "$FIX" = true ]; then
    ACTION="Update"
fi

# Construct and execute command
SCRIPT_PATH=".scripts/automation/spellcheck/Invoke-SpellCheck.ps1"
if [ -z "$PATH_TO_CHECK" ]; then
    echo "Executing: $PWSH_CMD -File $SCRIPT_PATH -Action $ACTION $VERBOSE_FLAG"
    $PWSH_CMD -File $SCRIPT_PATH -Action $ACTION $VERBOSE_FLAG
else
    echo "Executing: $PWSH_CMD -File $SCRIPT_PATH -Action $ACTION -Path $PATH_TO_CHECK $VERBOSE_FLAG"
    $PWSH_CMD -File $SCRIPT_PATH -Action $ACTION -Path "$PATH_TO_CHECK" $VERBOSE_FLAG
fi