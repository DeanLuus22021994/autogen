#!/bin/bash
# Script to run markdown linting on the repository

set -e

# Default paths
CONFIG_PATH=".github/linting/markdownlint-cli2.jsonc"
TARGET_PATHS=".github/**/*.md"

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --config)
      CONFIG_PATH="$2"
      shift
      shift
      ;;
    --target)
      TARGET_PATHS="$2"
      shift
      shift
      ;;
    --fix)
      FIX_OPTION="--fix"
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --config PATH    Path to config file (default: .github/linting/markdownlint-cli2.jsonc)"
      echo "  --target GLOB    Glob pattern for files to lint (default: .github/**/*.md)"
      echo "  --fix            Fix linting issues where possible"
      echo "  --help           Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Run linting
echo "Running markdown linting with config: $CONFIG_PATH"
echo "Target paths: $TARGET_PATHS"
echo ""

if [ -n "$FIX_OPTION" ]; then
  npx markdownlint-cli2 $TARGET_PATHS --config $CONFIG_PATH --fix
else
  npx markdownlint-cli2 $TARGET_PATHS --config $CONFIG_PATH
fi
