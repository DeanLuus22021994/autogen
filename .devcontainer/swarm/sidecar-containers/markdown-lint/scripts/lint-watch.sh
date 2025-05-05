#!/bin/sh
# Script to watch for changes in markdown files and execute linting

# Set default paths
WORKSPACE_PATH="/app/workspace"
CONFIG_PATH="/app/config/.markdownlint-cli2.jsonc"
RULES_PATH="/app/rules"

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
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
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "🔍 Watching for changes in markdown files..."
echo "Workspace: $WORKSPACE_PATH"
echo "Config: $CONFIG_PATH"
echo "Rules: $RULES_PATH"

# Use find to watch for changes
while true; do
  # Check for changed files in the last 5 seconds
  CHANGED_FILES=$(find "$WORKSPACE_PATH" -name "*.md" -type f -mtime -0.0001 2>/dev/null)

  if [ -n "$CHANGED_FILES" ]; then
    echo "📝 Changes detected in markdown files, running linting..."

    # Execute linting on changed files
    for file in $CHANGED_FILES; do
      echo "Linting $file..."
      markdownlint-cli2 --config "$CONFIG_PATH" "$file"
    done
  fi

  # Sleep for a short interval to avoid high CPU usage
  sleep 2
done
