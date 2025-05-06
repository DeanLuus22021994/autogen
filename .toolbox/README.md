# AutoGen Toolbox

This directory contains scripts, utilities, and tools to assist with AutoGen development, maintenance, and configuration. These tools follow the project's Enhanced Prompt Engineering Framework standards and are organized into functional categories.

## Directory Structure

- `docker/` - Docker Model Runner and container management tools
- `github/` - GitHub workflow and integration tools
- `markdown/` - Markdown linting and fixing tools
- `environment/` - Environment setup and validation tools
- `security/` - Security-related tools
- `config/` - Configuration management tools

## Usage Guidelines

1. All scripts should be run from the repository root directory unless specified otherwise
2. PowerShell scripts use a verb-noun naming convention (e.g., `Fix-DockerModelIntegration.ps1`)
3. Script names should clearly indicate their purpose and function
4. Each script should include proper documentation in comments at the beginning

## Common Tasks

### Docker Model Integration

```powershell
.\.toolbox\docker\Fix-DockerModelIntegration.ps1
```

### GitHub Workflow Fixes

```powershell
.\.toolbox\github\Fix-GitHubWorkflows.ps1
```

### Markdown Linting

```powershell
.\.toolbox\markdown\Add-MarkdownRulesFunction.ps1
```

### Environment Setup

```powershell
.\.toolbox\environment\Setup-AutogenEnvironment.ps1
```

## Adding New Tools

When adding new tools:

1. Place them in the appropriate category directory
2. Follow the naming convention of the directory
3. Document the tool in this README
4. Create or update the DIR.TAG file in the tool's directory
5. Include proper error handling and documentation within the script

## Maintenance

This toolbox is maintained as part of the AutoGen project. If you find issues or have suggestions for improvements, please open an issue or pull request on GitHub.
