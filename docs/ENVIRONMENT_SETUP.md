# Environment Setup Guide for Contributors

This guide explains how to set up your environment for contributing to the AutoGen project, including handling secrets and environment variables properly.

## Required Environment Variables

The following environment variables are required for development:

```
REPO_PATH="autogen"
FORK_AUTOGEN_OWNER=<your-github-username>
FORK_AUTOGEN_SSH_REPO_URL=<your-fork-repo-url>
FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN=<your-github-pat>
FORK_AUTOGEN_USER_DOCKER_USERNAME=<your-docker-username>
FORK_USER_DOCKER_ACCESS_TOKEN=<your-docker-token>
FORK_HUGGINGFACE_ACCESS_TOKEN=<your-huggingface-token>
```

## Automated Setup

We provide several PowerShell scripts to help you set up your environment:

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
