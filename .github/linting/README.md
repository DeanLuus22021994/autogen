# Markdown Linting Tools

This directory contains tools and configurations for enforcing consistent markdown formatting across the repository.

## Overview

The markdown linting system provides:

- Standardized rules for all markdown documents
- Automated validation and fixing of common issues
- Integration with VS Code and other editors
- Custom rules specific to the project's needs

## Setup

To set up the markdown linting environment:

```powershell
# From repository root
./.github/linting/Initialize-MarkdownLinting.ps1
```

This will ensure all necessary dependencies are installed and configuration files are properly set up.

## Configuration Files

- `.markdownlint-cli2.jsonc` - Main configuration for markdownlint-cli2
- `.markdownlintignore` - Patterns for files to exclude from linting
- `.markdownlintrc` - Legacy configuration for markdownlint compatibility
- `.markdownlint.json` - Configuration for VS Code extension

## Modules

The linting system is organized into several PowerShell modules:

- `core/MarkdownLintUtilities.psm1` - Common utilities
- `core/MarkdownLintConfig.psm1` - Configuration management
- `core/MarkdownLintRules.psm1` - Rules processing
- `scripts/Process-ShellCommands.ps1` - Shell command utilities
- `scripts/Update-VsCodeConfig.ps1` - VS Code integration
- `config/DefaultConfigs.psm1` - Configuration templates

## VS Code Integration

The system automatically configures VS Code tasks for markdown linting:

- **Lint Markdown** - Checks all markdown files for issues
- **Fix Markdown Issues** - Attempts to automatically fix common issues
- **Generate Markdown Report** - Creates a report of linting status

## Custom Rules

Custom rules can be added to the `.github/linting/rules/` directory as JavaScript files. These will be automatically loaded by the linting system.

## Troubleshooting

If you encounter issues with the linting system:

1. Ensure Node.js and npm are installed
2. Run `npm install -g markdownlint-cli2` to install the linter globally
3. Check for errors in the configuration files

For more help, see [markdownlint-cli2 documentation](https://github.com/DavidAnson/markdownlint-cli2).
