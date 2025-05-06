# Docker Tools

This directory contains tools for working with Docker in the AutoGen project, particularly focusing on Docker Model Runner integration.

## Available Tools

- `Fix-DockerModelIntegration.ps1` - Fixes issues with Docker Model Runner integration:
  - Removes unsupported model references
  - Updates XML schema elements
  - Ensures configuration consistency

- `Update-DockerExtensionModelRunner.ps1` - Updates Docker extension for Model Runner compatibility

- `Update-DockerExtension.ps1` - Updates general Docker extension components

## Usage

Run all scripts from the repository root directory:

```powershell
# Fix Docker Model integration issues
.\.toolbox\docker\Fix-DockerModelIntegration.ps1

# Update Docker extension for Model Runner
.\.toolbox\docker\Update-DockerExtensionModelRunner.ps1
```

## Requirements

- PowerShell 7.0+
- Docker Desktop 4.40+ (for running Docker Model Runner)
