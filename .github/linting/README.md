# Markdown Linting Tools

This directory contains the configuration and tools for markdown linting in the AutoGen project.

## Overview

The markdown linting system provides:

- Consistent style enforcement across all markdown documents
- Automated validation of documentation
- Integration with VS Code for real-time feedback
- Command-line tools for CI/CD integration
- Customizable rules specific to the project's needs

## Setup

To set up the markdown linting environment:

1. Ensure Node.js is installed (v14+ recommended)
2. Run the initialization script:

```powershell
# From the repository root
.\.github\linting\Initialize-MarkdownLinting.ps1
```

This will:
- Install required npm packages if needed
- Configure VS Code settings for the workspace
- Set up tasks for linting operations

## Usage

### VS Code Integration

The system automatically configures VS Code tasks for markdown linting:

- **Lint Markdown**: Run linting on the current file
- **Lint All Markdown**: Run linting on all markdown files
- **Fix Markdown Issues**: Attempt to automatically fix issues

These tasks can be accessed via the Command Palette (Ctrl+Shift+P) by typing "Tasks: Run Task".

### Command Line

```powershell
# Toggle linting on/off
.\.github\linting\Toggle-MarkdownLinting.ps1 -Enable

# Run linting on specific files
.\.github\linting\Invoke-MarkdownLint.ps1 -Path path\to\file.md

# Run linting on all files
.\.github\linting\Invoke-MarkdownLint.ps1

# Run the simplified linting script
.\.github\linting\run-markdown-lint.ps1

# Fix markdown issues automatically
.\.github\linting\run-markdown-lint.ps1 -Fix

# Validate linting configuration
.\.github\linting\run-lint-check.ps1
```

## Configuration

The configuration files in this directory are the single source of truth for markdown linting:

- .markdownlint-cli2.jsonc: Primary configuration for markdownlint-cli2
- .markdownlintrc: Alternative configuration format for IDE integration
- .markdownlint.json: JSON configuration for IDE integration
- .markdownlintignore: Files to exclude from linting

## Custom Rules

Custom rules are stored in the `rules` directory. These provide project-specific checks beyond the standard rules.

### Example Rule

A basic example rule is provided to ensure the rules directory has valid content. This rule checks that heading lines are not too long.

```javascript
// .github/linting/rules/example-rule.js
// Basic example rule to ensure the rules directory has valid content

"use strict";

module.exports = {
  names: ["example-rule"],
  description: "Example custom rule",
  tags: ["autogen", "example"],
  function: function rule(params, onError) {
    params.tokens.filter(function filterToken(token) {
      return token.type === "heading_open";
    }).forEach(function forToken(token) {
      if (token.line.trim().length > 80) {
        onError({
          lineNumber: token.lineNumber,
          detail: "Heading line is too long",
          context: token.line.trim()
        });
      }
    });
  }
};
```

## Adding Rules

To add a new custom rule:

1. Create a JavaScript file in the `rules` directory
2. Follow the markdownlint plugin pattern
3. Test the rule against sample documents

See the README.md file for more details.

## Troubleshooting

If you encounter issues with markdown linting:

1. Ensure all dependencies are installed
2. Check the configuration files for syntax errors
3. Verify that the rules directory exists and contains valid rule files
4. Try running the linting tools with the `-Verbose` flag for additional information

For more help:

```powershell
# Get detailed information about the current status
.\.github\linting\Toggle-MarkdownLinting.ps1 -Status

# Validate the linting configuration
.\.github\linting\run-lint-check.ps1
```

## Directory Structure

```
.github/linting/
├── config/                 # Configuration storage
├── core/                   # Core functionality modules
├── rules/                  # Custom markdown linting rules
├── scripts/                # Utility scripts
├── utils/                  # Helper functions
├── Initialize-MarkdownLinting.ps1  # Setup script
├── Invoke-MarkdownLint.ps1         # Main linting script
├── MarkdownLintHelpers.psm1        # PowerShell module with helper functions
├── README.md                       # This documentation
├── Toggle-MarkdownLinting.ps1      # Enable/disable linting
├── markdown-tasks.code-tasks       # VS Code tasks template
├── run-markdown-lint.ps1           # Simplified linting script
└── run-lint-check.ps1              # Configuration validator
```
