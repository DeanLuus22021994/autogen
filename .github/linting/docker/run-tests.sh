#!/bin/sh
# Script to run markdown linting tests inside Docker container
# This provides instant startup for testing markdown rules

set -e

# Parse command line arguments
HELP=false
TEST_DIR=""
CONFIG_PATH=""
RULES_DIR=""
VERBOSE=false
SPECIFIC_FILE=""

# Display help information
show_help() {
  echo "Usage: run-tests.sh [options]"
  echo ""
  echo "Options:"
  echo "  --test-dir DIR       Directory containing markdown files to test"
  echo "  --config PATH        Path to markdownlint-cli2 config file"
  echo "  --rules-dir DIR      Directory containing custom markdown rules"
  echo "  --file PATH          Test a specific markdown file"
  echo "  --verbose            Enable verbose output"
  echo "  --help               Display this help message"
  echo ""
  echo "Example:"
  echo "  run-tests.sh --test-dir /app/test --config /app/config/.markdownlint-cli2.jsonc --rules-dir /app/rules"
}

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help)
      HELP=true
      shift 1
      ;;
    --test-dir)
      TEST_DIR="$2"
      shift 2
      ;;
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --rules-dir)
      RULES_DIR="$2"
      shift 2
      ;;
    --file)
      SPECIFIC_FILE="$2"
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

# Show help if requested or if required arguments are missing
if [ "$HELP" = true ] || [ -z "$TEST_DIR" ] || [ -z "$CONFIG_PATH" ]; then
  show_help
  exit 0
fi

# Prepare environment
echo "🔍 Initializing markdown linting test environment..."
if [ "$VERBOSE" = true ]; then
  echo "Test directory: $TEST_DIR"
  echo "Config file: $CONFIG_PATH"
  echo "Rules directory: $RULES_DIR"
  if [ -n "$SPECIFIC_FILE" ]; then
    echo "Specific file: $SPECIFIC_FILE"
  fi
fi

# Create a temporary config file if custom rules are specified
if [ -n "$RULES_DIR" ]; then
  echo "📋 Loading custom rules from $RULES_DIR"
  # Create a temporary JSON file that imports the base config and adds customRules
  TMP_CONFIG="/tmp/markdownlint-config.json"

  # Extract config content without the final closing brace
  if [ -f "$CONFIG_PATH" ]; then
    sed 's/}[[:space:]]*$//' "$CONFIG_PATH" > "$TMP_CONFIG"
    # Add custom rules directory to config
    echo "  ,\"customRules\": [\"$RULES_DIR/*.js\"]" >> "$TMP_CONFIG"
    echo "}" >> "$TMP_CONFIG"

    CONFIG_PATH="$TMP_CONFIG"

    if [ "$VERBOSE" = true ]; then
      echo "Generated temporary config:"
      cat "$TMP_CONFIG"
    fi
  else
    echo "⚠️ Config file not found: $CONFIG_PATH"
    exit 1
  fi
fi

# Run markdownlint-cli2
echo "🚀 Running markdown lint tests..."

# Set target based on whether a specific file was specified
if [ -n "$SPECIFIC_FILE" ]; then
  # Test a specific file
  if [ -f "$SPECIFIC_FILE" ]; then
    TARGET="$SPECIFIC_FILE"
  else
    echo "⚠️ Specified file not found: $SPECIFIC_FILE"
    exit 1
  fi
else
  # Test all markdown files in the test directory
  TARGET="$TEST_DIR/**/*.md"
fi

# Execute the linting command with appropriate verbosity
if [ "$VERBOSE" = true ]; then
  echo "Command: npx markdownlint-cli2 --config \"$CONFIG_PATH\" \"$TARGET\""
  npx markdownlint-cli2 --config "$CONFIG_PATH" "$TARGET"
else
  # Redirect output to temporary file to check status
  npx markdownlint-cli2 --config "$CONFIG_PATH" "$TARGET" > /tmp/lint-results.txt 2>&1
  LINT_STATUS=$?

  # Check if there were any errors
  if [ $LINT_STATUS -ne 0 ]; then
    cat /tmp/lint-results.txt
    echo "❌ Markdown linting failed. See errors above."
    exit 1
  else
    echo "✅ All markdown files passed linting tests!"
  fi
fi

echo "✨ Test execution complete!"
exit 0
