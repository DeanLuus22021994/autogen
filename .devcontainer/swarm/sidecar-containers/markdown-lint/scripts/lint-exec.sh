#!/bin/sh
# Script to execute linting on specified files or directories

# Set default paths
WORKSPACE_PATH="/app/workspace"
CONFIG_PATH="/app/config/.markdownlint-cli2.jsonc"
RULES_PATH="/app/rules"
TARGET_PATH=""
VERBOSE=false

# Display help
show_help() {
  echo "Usage: lint-exec.sh [options]"
  echo ""
  echo "Options:"
  echo "  --workspace PATH   Path to workspace directory (default: /app/workspace)"
  echo "  --config PATH      Path to config file (default: /app/config/.markdownlint-cli2.jsonc)"
  echo "  --rules PATH       Path to rules directory (default: /app/rules)"
  echo "  --target PATH      Specific file or directory to lint (default: entire workspace)"
  echo "  --verbose          Enable verbose output"
  echo ""
}

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --workspace)
      WORKSPACE_PATH="$2"
      shift 2
      ;;
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --rules)
      RULES_PATH="$2"
      shift 2
      ;;
    --target)
      TARGET_PATH="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift 1
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Set the target path
if [ -z "$TARGET_PATH" ]; then
  TARGET_PATH="$WORKSPACE_PATH/**/*.md"
fi

# Create a temporary config file that includes custom rules if needed
if [ -d "$RULES_PATH" ] && [ "$(ls -A "$RULES_PATH")" ]; then
  echo "📋 Using custom rules from $RULES_PATH"

  TEMP_CONFIG="/tmp/markdownlint-config-$(date +%s).json"

  # Extract base config content without final closing brace
  if [ -f "$CONFIG_PATH" ]; then
    sed 's/}[[:space:]]*$//' "$CONFIG_PATH" > "$TEMP_CONFIG"

    # Add custom rules directory
    echo '  ,"customRules": ["'$RULES_PATH'/*.js"]' >> "$TEMP_CONFIG"
    echo "}" >> "$TEMP_CONFIG"

    CONFIG_PATH="$TEMP_CONFIG"

    if [ "$VERBOSE" = true ]; then
      echo "Generated temporary config:"
      cat "$TEMP_CONFIG"
    fi
  fi
fi

# Execute linting
echo "🚀 Running markdown linting..."
if [ "$VERBOSE" = true ]; then
  echo "Command: markdownlint-cli2 --config \"$CONFIG_PATH\" \"$TARGET_PATH\""
fi

# Run linting and capture exit code
markdownlint-cli2 --config "$CONFIG_PATH" "$TARGET_PATH"
LINT_EXIT_CODE=$?

# Clean up temp file if created
if [ -f "$TEMP_CONFIG" ]; then
  rm "$TEMP_CONFIG"
fi

# Report results
if [ $LINT_EXIT_CODE -eq 0 ]; then
  echo "✅ Linting passed successfully!"
else
  echo "❌ Linting found issues."
fi

exit $LINT_EXIT_CODE
