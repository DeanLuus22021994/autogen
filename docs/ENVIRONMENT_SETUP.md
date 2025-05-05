# Environment Setup Guide for Contributors

This document explains how to set up your development environment for contributing to AutoGen. The setup includes configuring Git, environment variables, and VS Code.

## Prerequisites

- [PowerShell 7.0+](https://github.com/PowerShell/PowerShell)
- [Git](https://git-scm.com/)
- [Python 3.8+](https://www.python.org/)
- [Visual Studio Code](https://code.visualstudio.com/)

## Recommended VS Code Extensions

The following extensions are recommended for AutoGen development:

- `charliermarsh.ruff`: Python linter
- `matangover.mypy`: Type checking for Python
- `ms-python.python`: Python language support
- `ms-python.vscode-pylance`: Python language server
- `github.vscode-github-actions`: GitHub Actions support
- `davidanson.vscode-markdownlint`: Markdown linting
- `redhat.vscode-yaml`: YAML support

### Setup-GitSecureEnvironment.ps1

This script helps set up a secure Git environment and helps clean sensitive data from the repository.

```powershell
# Set up Git configuration
.\Setup-GitSecureEnvironment.ps1 -SetupGit

# Clean repository history of sensitive data
.\Setup-GitSecureEnvironment.ps1 -CleanHistory

# Configure GitHub CLI
.\Setup-GitSecureEnvironment.ps1 -ConfigureGitHubCLI
```

### Validate-EnvSecrets.ps1

This script validates and manages environment variables and secrets for the AutoGen repository.

```powershell
# Validate environment variables
.\Validate-EnvSecrets.ps1 -Validate

# Set up missing environment variables
.\Validate-EnvSecrets.ps1 -Setup

# Fix configuration files to use environment variables
.\Validate-EnvSecrets.ps1 -Fix
```

### Commit-SafeVsCodeConfig.ps1

This script safely commits VS Code configuration files after ensuring no tokens are exposed.

```powershell
# Check VS Code config files for security issues
.\Commit-SafeVsCodeConfig.ps1

# Force update and commit VS Code config files
.\Commit-SafeVsCodeConfig.ps1 -Force -Message "update: VS Code configuration"
```

### Resolve-PushBlockedByToken.ps1

This script helps resolve GitHub push protection issues due to detected tokens.

```powershell
# Fix token issue in repository
.\Resolve-PushBlockedByToken.ps1 -Fix

# Unblock a secret (only for revoked tokens)
.\Resolve-PushBlockedByToken.ps1 -Unblock -UnblockURL 'https://github.com/...'
```

### Verify-GitHubSecrets.ps1

This script verifies that required secrets are set in GitHub Actions for the repository.

```powershell
# Verify GitHub secrets
.\Verify-GitHubSecrets.ps1

# Attempt to set missing secrets
.\Verify-GitHubSecrets.ps1 -FixMissingSecrets
```

## Best Practices for Security

1. **Never commit secrets directly**: Always use environment variables
2. **Use environment variable references**: For VS Code configuration files, use `${env:VARIABLE_NAME}` syntax
3. **Regularly validate your setup**: Run `Validate-EnvSecrets.ps1 -Validate` before committing
4. **Use secure commit process**: Use `Commit-SafeVsCodeConfig.ps1` when updating VS Code files
5. **Check GitHub Actions secrets**: Ensure your repository has the required secrets set

1. `Setup-AutogenEnvironment.ps1` - Master script that orchestrates the complete setup
2. `Validate-EnvSecrets.ps1` - Validates and sets up environment variables and secrets
3. `Setup-GitSecureEnvironment.ps1` - Configures Git for secure development
4. `Resolve-PushBlockedByToken.ps1` - Helps resolve GitHub push protection issues

To set up your environment, you can use the master script:

```powershell
# Complete setup and validation
.\Setup-AutogenEnvironment.ps1 -All

# Just initialize the environment
.\Setup-AutogenEnvironment.ps1 -Initialize

# Just validate the environment
.\Setup-AutogenEnvironment.ps1 -Validate

# Fix token issues
.\Setup-AutogenEnvironment.ps1 -FixTokens
```

Or use individual scripts for more granular control:

```powershell
# Set up environment variables and GitHub secrets
.\Validate-EnvSecrets.ps1 -Setup

# Configure Git for secure development
.\Setup-GitSecureEnvironment.ps1 -SetupGit

# If you have push protection issues
.\Resolve-PushBlockedByToken.ps1
```

## Best Practices for Security

1. **Never commit tokens to version control**
   - Use environment variables instead
   - Reference tokens in configuration files using `${env:VARIABLE_NAME}`

2. **Use the GitHub CLI for automation**
   - Configure GitHub CLI with your PAT: `gh auth login --with-token`

3. **Keep secrets in GitHub Actions secrets**
   - Store sensitive values in GitHub repository secrets
   - Reference them in workflows using `${{ secrets.SECRET_NAME }}`

## Troubleshooting

If you encounter the "Repository rule violations found" error when pushing:

1. Check if you accidentally committed a token
2. Run `.\Resolve-PushBlockedByToken.ps1 -Fix` to fix the issue
3. If the token is already invalid, you can unblock it with the URL from the error
