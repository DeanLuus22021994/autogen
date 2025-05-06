# AutoGen Toolbox Index

This file provides a comprehensive index of all scripts available in the `.toolbox` directory.

## Docker Tools (.toolbox/docker/)

| Script | Purpose |
|--------|---------|
| Fix-DockerModelIntegration.ps1 | Fixes Docker Model Runner integration issues |
| Update-DockerExtensionModelRunner.ps1 | Updates Docker extension for Model Runner compatibility |
| Update-DockerExtension.ps1 | Updates general Docker extension components |

## GitHub Tools (.toolbox/github/)

| Script | Purpose |
|--------|---------|
| Fix-GitHubWorkflows.ps1 | Fixes issues with GitHub workflow files |
| Setup-GitHubSSH.ps1 | Sets up SSH access for GitHub |
| Setup-GitSecureEnvironment.ps1 | Configures a secure Git environment |
| Resolve-PushBlockedByToken.ps1 | Resolves issues with push operations blocked by token |

## Markdown Tools (.toolbox/markdown/)

| Script | Purpose |
|--------|---------|
| Add-MarkdownRulesFunction.ps1 | Adds custom functions for markdown rule validation |

## Environment Tools (.toolbox/environment/)

| Script | Purpose |
|--------|---------|
| Setup-AutogenEnvironment.ps1 | Sets up the AutoGen development environment |
| Reset-VSCodeEnvironment.ps1 | Resets the VS Code environment settings |

## Security Tools (.toolbox/security/)

| Script | Purpose |
|--------|---------|
| Validate-EnvSecrets.ps1 | Validates environment secrets |
| Verify-GitHubSecrets.ps1 | Verifies GitHub secrets are configured correctly |

## Configuration Tools (.toolbox/config/)

| Script | Purpose |
|--------|---------|
| Commit-SafeVsCodeConfig.ps1 | Commits VS Code configuration files safely |

## Common Tasks

### Docker-related Tasks

```powershell
# Fix Docker Model integration issues
.\.toolbox\docker\Fix-DockerModelIntegration.ps1
```

### GitHub-related Tasks

```powershell
# Fix GitHub workflow issues
.\.toolbox\github\Fix-GitHubWorkflows.ps1
```

### Environment Setup

```powershell
# Set up AutoGen environment
.\.toolbox\environment\Setup-AutogenEnvironment.ps1
```
