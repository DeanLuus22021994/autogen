# AutoGen Toolbox Documentation

> Generated on: 2025-05-06 02:35:37
> Version: 1.0.0


      Catalog of toolbox scripts and utilities for the AutoGen project.
      Used for discovery and documentation of available tools.
    

## Table of Contents

- [Docker Tools](#docker)
- [GitHub Tools](#github)
- [Markdown Tools](#markdown)
- [Environment Tools](#environment)
- [Security Tools](#security)
- [Configuration Tools](#config)

## Categories and Tools

### Docker Tools {#docker}

Tools for Docker integration and management

| Tool | Description | Tags |
|------|-------------|------|
| [Fix-DockerModelIntegration.ps1](.toolbox/docker/Fix-DockerModelIntegration.ps1) | Fixes issues with Docker Model Runner integration | docker,model-runner,integration,xml |
| [Update-DockerExtensionModelRunner.ps1](.toolbox/docker/Update-DockerExtensionModelRunner.ps1) | Updates Docker extension for Model Runner compatibility | docker,model-runner,extension |
| [Update-DockerExtension.ps1](.toolbox/docker/Update-DockerExtension.ps1) | Updates general Docker extension components | docker,extension |

### GitHub Tools {#github}

Tools for GitHub workflows and integration

| Tool | Description | Tags |
|------|-------------|------|
| [Fix-GitHubWorkflows.ps1](.toolbox/github/Fix-GitHubWorkflows.ps1) | Fixes issues with GitHub workflow files | github,workflows,yaml |
| [Setup-GitHubSSH.ps1](.toolbox/github/Setup-GitHubSSH.ps1) | Sets up SSH access for GitHub | github,ssh,security |
| [Setup-GitSecureEnvironment.ps1](.toolbox/github/Setup-GitSecureEnvironment.ps1) | Configures a secure Git environment | github,security,git |
| [Resolve-PushBlockedByToken.ps1](.toolbox/github/Resolve-PushBlockedByToken.ps1) | Resolves issues with push operations blocked by token | github,token,authentication |

### Markdown Tools {#markdown}

Tools for markdown linting and fixing

| Tool | Description | Tags |
|------|-------------|------|
| [Add-MarkdownRulesFunction.ps1](.toolbox/markdown/Add-MarkdownRulesFunction.ps1) | Adds custom functions for markdown rule validation | markdown,linting,rules |

### Environment Tools {#environment}

Tools for environment setup and validation

| Tool | Description | Tags |
|------|-------------|------|
| [Setup-AutogenEnvironment.ps1](.toolbox/environment/Setup-AutogenEnvironment.ps1) | Sets up the AutoGen development environment | environment,setup |
| [Reset-VSCodeEnvironment.ps1](.toolbox/environment/Reset-VSCodeEnvironment.ps1) | Resets the VS Code environment settings | vscode,environment,reset |

### Security Tools {#security}

Tools for security management

| Tool | Description | Tags |
|------|-------------|------|
| [Validate-EnvSecrets.ps1](.toolbox/security/Validate-EnvSecrets.ps1) | Validates environment secrets | security,secrets,environment |
| [Verify-GitHubSecrets.ps1](.toolbox/security/Verify-GitHubSecrets.ps1) | Verifies GitHub secrets are configured correctly | security,github,secrets |

### Configuration Tools {#config}

Tools for configuration management

| Tool | Description | Tags |
|------|-------------|------|
| [Commit-SafeVsCodeConfig.ps1](.toolbox/config/Commit-SafeVsCodeConfig.ps1) | Commits VS Code configuration files safely | vscode,config,git |

