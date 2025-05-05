# Environment Configuration for AutoGen

This document explains how to set up your environment variables for working with the AutoGen repository.

## Required Environment Variables

The following environment variables need to be set on your system or in GitHub Secrets for Actions:

### Repository Configuration

- `REPO_PATH`: The name of the repository (default: "autogen")

### GitHub Configuration

- `FORK_AUTOGEN_OWNER`: Your GitHub username (e.g., "DeanLuus22021994")
- `FORK_AUTOGEN_SSH_REPO_URL`: The HTTPS URL to your forked repository
- `FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN`: Your GitHub Personal Access Token (PAT)

### Docker Configuration

- `FORK_AUTOGEN_USER_DOCKER_USERNAME`: Your Docker Hub username
- `FORK_USER_DOCKER_ACCESS_TOKEN`: Your Docker Hub access token

### API Tokens

- `FORK_HUGGINGFACE_ACCESS_TOKEN`: Your Hugging Face access token

## Setting Environment Variables

### For Windows

Set environment variables using PowerShell:

```powershell
[Environment]::SetEnvironmentVariable("FORK_AUTOGEN_OWNER", "YourGitHubUsername", "User")
[Environment]::SetEnvironmentVariable("FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN", "your-github-pat", "User")
```

### For Linux/Mac

Set environment variables in your shell profile (~/.bashrc, ~/.zshrc, etc.):

```bash
export FORK_AUTOGEN_OWNER="YourGitHubUsername"
export FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN="your-github-pat"
```

## For GitHub Actions

Add these values as repository secrets in your GitHub repository:
1. Go to your repository on GitHub
2. Click on "Settings" > "Secrets and variables" > "Actions"
3. Add each environment variable as a secret

## Validation

You can validate your environment setup by running the "Validate Environment Setup" GitHub Action in your repository.

## Troubleshooting

### Git Authentication Errors

If you encounter Git authentication errors (e.g., "Permission denied (publickey)"), you can use our fix scripts:

#### Automatic Fix Scripts (No Prompts)

1. For Windows users:

   ```powershell
   cd .devcontainer
   .\auto-fix-git-auth.ps1
   ```

2. For Linux/Mac users:

   ```bash
   cd .devcontainer
   chmod +x auto-fix-git-auth.sh
   ./auto-fix-git-auth.sh
   ```

These scripts will automatically configure Git to use HTTPS with a personal access token from your environment variables.

#### Interactive Fix Scripts (With Prompts)

1. For Windows users:

   ```powershell
   cd .devcontainer
   .\setup-environment.ps1
   ```

2. For Linux/Mac users:

   ```bash
   cd .devcontainer
   chmod +x setup-environment.sh
   ./setup-environment.sh
   ```

These scripts will:

1. Prompt you for your GitHub username and personal access token
2. Configure Git to use HTTPS with your token instead of SSH
3. Test the connection to verify it works
4. Optionally save these credentials as environment variables

#### Manual Fix

If the quick-fix scripts don't resolve your issue, you can manually configure Git:

1. Ensure your Personal Access Token has the correct scopes (repo, workflow, packages)
2. Configure Git to use HTTPS with your token:

   ```bash
   git config --global url."https://YOUR_TOKEN@github.com/YOUR_USERNAME".insteadOf "git@github.com:YOUR_USERNAME"
   git config --global url."https://YOUR_TOKEN@github.com/YOUR_USERNAME".insteadOf "https://github.com/YOUR_USERNAME"
   ```
   ```
3. Verify that the repo exists and you have proper access permissions
