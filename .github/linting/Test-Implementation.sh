#!/bin/bash
# Test script for markdown linting implementation
# This script will verify that the Docker-based rule testing system works as expected

echo "🧪 Testing Markdown Linting Implementation"
echo "=========================================="

# Ensure we're in the repository root
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || { echo "❌ Failed to navigate to repository root"; exit 1; }

# Check if required directories exist
LINTING_DIR=".github/linting"
DOCKER_DIR="$LINTING_DIR/docker"
EXAMPLES_DIR="$LINTING_DIR/examples"
RULES_DIR="$LINTING_DIR/rules"

for dir in "$LINTING_DIR" "$DOCKER_DIR" "$EXAMPLES_DIR" "$RULES_DIR"; do
  if [ ! -d "$dir" ]; then
    echo "❌ Missing directory: $dir"
    exit 1
  else
    echo "✅ Found directory: $dir"
  fi
done

# Check if required files exist
DOCKER_FILE="$DOCKER_DIR/Dockerfile"
RUN_TESTS_SCRIPT="$DOCKER_DIR/run-tests.sh"
TEST_SCRIPT="$LINTING_DIR/Test-MarkdownRules.ps1"
SPECIFIC_RULE_SCRIPT="$LINTING_DIR/Test-SpecificRule.ps1"
CONFIG_FILE="$LINTING_DIR/.markdownlint-cli2.jsonc"
EXAMPLE_FILE="$EXAMPLES_DIR/test-example.md"
SAMPLE_RULE="$RULES_DIR/sample-rule.js"

for file in "$DOCKER_FILE" "$RUN_TESTS_SCRIPT" "$TEST_SCRIPT" "$SPECIFIC_RULE_SCRIPT" "$CONFIG_FILE" "$EXAMPLE_FILE"; do
  if [ ! -f "$file" ]; then
    echo "❌ Missing file: $file"
    exit 1
  else
    echo "✅ Found file: $file"
  fi
done

# Check if Docker is available
if ! command -v docker &> /dev/null; then
  echo "❌ Docker is not installed or not in PATH"
  exit 1
else
  echo "✅ Docker is available"
fi

# Build the Docker container
echo -e "\n📦 Building Docker container for markdown linting..."
docker build -t autogen-markdown-lint -f "$DOCKER_FILE" "$DOCKER_DIR"
if [ $? -ne 0 ]; then
  echo "❌ Failed to build Docker container"
  exit 1
else
  echo "✅ Docker container built successfully"
fi

# Test the rule execution
echo -e "\n🔍 Testing markdown rule execution..."
pwsh -File "$TEST_SCRIPT" -Path "$EXAMPLES_DIR" -RulesDirectory "$RULES_DIR" -ConfigFile "$CONFIG_FILE" -BuildContainer
if [ $? -ne 0 ]; then
  echo "❌ Rule testing failed"
  exit 1
else
  echo "✅ Rule testing successful"
fi

# Test specific rule
if [ -f "$SAMPLE_RULE" ]; then
  echo -e "\n🔍 Testing specific rule execution..."
  pwsh -File "$SPECIFIC_RULE_SCRIPT" -RuleName "sample-rule" -UseDocker
  if [ $? -ne 0 ]; then
    echo "❌ Specific rule testing failed"
    exit 1
  else
    echo "✅ Specific rule testing successful"
  fi
else
  echo "⚠️ Sample rule file not found, skipping specific rule test"
fi

echo -e "\n🎉 Implementation test completed successfully!"
echo "The Docker-based markdown linting system is working as expected"
exit 0
