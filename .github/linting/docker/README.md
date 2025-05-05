# Docker-based Markdown Linting

This directory contains tools for testing markdown linting rules using Docker with instant startup times.

## Overview

The Docker-based markdown linting system provides:

1. **Fast Startup**: Optimized container configuration for instant testing
2. **Rule Testing**: Easy validation of custom markdown rules
3. **CI/CD Integration**: Ready for continuous integration workflows
4. **Dynamic Rule Loading**: Tests dynamically reference rules in the `.github` folder

## Components

- `docker/Dockerfile`: Optimized container for markdown rule testing
- `docker/run-tests.sh`: Shell script to run inside container
- `Test-MarkdownRules.ps1`: PowerShell script to manage test execution
- `config/DockerConfig.json`: Configuration for container testing

## Usage

### Testing Markdown Rules

Run the PowerShell script to test markdown files against the rules:

```powershell
# Test with default settings
.\Test-MarkdownRules.ps1

# Test with specific options
.\Test-MarkdownRules.ps1 -Path docs -RulesDirectory custom-rules -BuildContainer -Detailed
```

### Options

- `-Path`: Directory containing markdown files to test (default: repository root)
- `-RulesDirectory`: Directory containing custom rules (default: .github/linting/rules)
- `-ConfigFile`: Path to config file (default: .github/linting/.markdownlint-cli2.jsonc)
- `-BuildContainer`: Rebuild Docker container before testing
- `-Local`: Run tests locally instead of in Docker
- `-Detailed`: Show detailed output

### VS Code Integration

The system integrates with VS Code tasks. Add this to your `.vscode/tasks.json`:

```json
{
  "label": "Test Markdown Rules",
  "type": "shell",
  "command": "pwsh",
  "args": [
    "-File",
    "${workspaceFolder}/.github/linting/Test-MarkdownRules.ps1",
    "-Detailed"
  ],
  "group": {
    "kind": "test",
    "isDefault": false
  }
}
```

## Implementation Details

### Fast Startup Techniques

The Docker implementation uses several techniques from the [CircleCI documentation](https://circleci.com/docs/using-docker/) to achieve instant startup:

1. **Alpine Base**: Uses lightweight Alpine Linux base image
2. **Layer Caching**: Optimized layer structure for better caching
3. **Pre-warming**: Pre-warms the Node.js runtime during build
4. **Volume Mounting**: Uses volume mounts instead of copying files

### Custom Rule Development

Custom rules are dynamically loaded from the rules directory. To create a new rule:

1. Create a JavaScript file in the `.github/linting/rules` directory
2. Follow the markdownlint rule format (see sample-rule.js)
3. Run the test script to validate your rule

## Requirements

- Docker Desktop (for container-based testing)
- PowerShell 7+ (for running the script)
- Node.js and markdownlint-cli2 (for local testing only)

## CI/CD Integration

To integrate with GitHub Actions workflows:

```yaml
- name: Test Markdown Rules
  run: |
    pwsh -File .github/linting/Test-MarkdownRules.ps1 -BuildContainer
```
