# AutoGen Automation Scripts

This directory contains modular automation scripts for the AutoGen project, designed to help with environment setup, security, and configuration management.

## Directory Structure

- **common/**: Common utility functions and shared code
- **config/**: Configuration management scripts
- **security/**: Security-focused scripts for token scanning and remediation
- **validation/**: Environment and setup validation scripts
- **orchestration/**: Main entry point scripts that combine functionality from other modules

## Core Modules

- **Common.psm1**: Common utilities and shared functions
- **Environment.psm1**: Environment variable management
- **Security.psm1**: Token scanning and security validation
- **Git.psm1**: Git operations and repository management
- **VSCode.psm1**: VS Code configuration and integration

## Orchestration Scripts

- **Validate-Environment.ps1**: Checks environment configuration
- **Repair-SecurityIssues.ps1**: Identifies and fixes security issues
- **Commit-VSCodeConfig.ps1**: Safely commits VS Code configuration
- **Verify-GitHubSetup.ps1**: Verifies GitHub repository settings

## Usage

These scripts can be run directly from PowerShell 7.0+ or through VS Code tasks:

```powershell
# Run environment validation
pwsh -File .\.scripts\automation\github\orchestration\Validate-Environment.ps1

# Fix security issues
pwsh -File .\.scripts\automation\github\orchestration\Repair-SecurityIssues.ps1

# Commit VS Code configuration
pwsh -File .\.scripts\automation\github\orchestration\Commit-VSCodeConfig.ps1

# Verify GitHub setup
pwsh -File .\.scripts\automation\github\orchestration\Verify-GitHubSetup.ps1
```

## VS Code Integration

These scripts are integrated with VS Code through tasks that can be run from the Command Palette (Ctrl+Shift+P) by selecting "Tasks: Run Task" and choosing the desired operation.

## Requirements

- PowerShell 7.0+
- Git
- VS Code (for running tasks)
- Python 3.8+ (for Python-related validation)

## Future Enhancements

- Expanded test coverage for scripts
- Additional automation for CI/CD workflows
- Support for container-based development environments
- Integration with DevOps pipelines

## Contributing

When contributing to these scripts, please follow these guidelines:

1. Use PowerShell best practices and approved verbs
2. Include comprehensive documentation in all functions
3. Add proper error handling and user feedback
4. Follow the modular architecture pattern
5. Test changes thoroughly before submitting PRs
