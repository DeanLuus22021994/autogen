#!/bin/bash
# Script to lint markdown files using the build tools container

# Set default values
TARGET_PATH=""
VERBOSE=false
CONFIG_PATH="/workspace/.github/linting/.markdownlint-cli2.jsonc"
RULES_PATH="/workspace/.github/linting/rules"
FIX=false

function show_help {
  echo "Usage: lint-markdown.sh [options] <target_path>"
  echo ""
  echo "Options:"
  echo "  --config PATH    Path to markdownlint config file"
  echo "                   (default: /workspace/.github/linting/.markdownlint-cli2.jsonc)"
  echo "  --rules PATH     Path to custom rules directory"
  echo "                   (default: /workspace/.github/linting/rules)"
  echo "  --fix            Fix issues where possible"
  echo "  --verbose        Show detailed output"
  echo "  --help           Show this help message"
  echo ""
  echo "Examples:"
  echo "  lint-markdown.sh /workspace/README.md"
  echo "  lint-markdown.sh --fix --verbose /workspace/docs"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --rules)
      RULES_PATH="$2"
      shift 2
      ;;
    --fix)
      FIX=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
    *)
      TARGET_PATH="$1"
      shift
      ;;
  esac
done

# Check if target path is provided
if [ -z "$TARGET_PATH" ]; then
  echo "Error: Target path is required"
  show_help
  exit 1
fi

# Check if target path exists
if [ ! -e "$TARGET_PATH" ]; then
  echo "Error: Target path does not exist: $TARGET_PATH"
  exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_PATH" ]; then
  echo "Warning: Config file not found at $CONFIG_PATH"
  echo "Will use default markdownlint rules"
fi

# Build the command
COMMAND="markdownlint-cli2"

if [ -f "$CONFIG_PATH" ]; then
  COMMAND="$COMMAND --config $CONFIG_PATH"
fi

if [ -d "$RULES_PATH" ]; then
  COMMAND="$COMMAND --rules $RULES_PATH/*.js"
else
  echo "Warning: Custom rules directory not found at $RULES_PATH"
fi

if [ "$FIX" = true ]; then
  COMMAND="$COMMAND --fix"
fi

if [ "$VERBOSE" = true ]; then
  COMMAND="$COMMAND --verbose"
fi

# Execute the command
echo "Running markdown linting on: $TARGET_PATH"
eval "$COMMAND \"$TARGET_PATH\""
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ Markdown linting passed"
else
  echo "❌ Markdown linting failed"
fi

exit $EXIT_CODE
