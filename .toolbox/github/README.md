# GitHub Tools

This directory contains tools for working with GitHub workflows and integration in the AutoGen project.

## Available Tools

- `Fix-GitHubWorkflows.ps1` - Fixes issues with GitHub workflow files:
  - Corrects invalid inputs in workflow definitions
  - Addresses GitHub context access warnings
  - Ensures proper action syntax

- `Setup-GitHubSSH.ps1` - Sets up SSH access for GitHub

- `Setup-GitSecureEnvironment.ps1` - Configures a secure Git environment

- `Resolve-PushBlockedByToken.ps1` - Resolves issues with push operations blocked by token issues

## Usage

Run all scripts from the repository root directory:

```powershell
# Fix GitHub workflow issues
.\.toolbox\github\Fix-GitHubWorkflows.ps1

# Set up SSH access for GitHub
.\.toolbox\github\Setup-GitHubSSH.ps1
```

## Requirements

- PowerShell 7.0+
- Git client
