# AutoGen Orchestration Scripts

This directory contains the main orchestration scripts for managing the AutoGen development environment.

## Available Scripts

### Validate-Environment.ps1

Validates that your development environment is properly configured for AutoGen development.

```powershell
# Run the validation script
pwsh -File .\Validate-Environment.ps1
```

### Repair-SecurityIssues.ps1

Identifies and fixes security issues in the repository.

```powershell
# Run the security repair script
pwsh -File .\Repair-SecurityIssues.ps1
```

### Commit-VSCodeConfig.ps1

Safely commits VS Code configuration files after checking for security issues.

```powershell
# Commit VS Code configuration files
pwsh -File .\Commit-VSCodeConfig.ps1
```

### Verify-GitHubSetup.ps1

Verifies and configures GitHub repository settings.

```powershell
# Verify GitHub repository setup
pwsh -File .\Verify-GitHubSetup.ps1
```

## VS Code Tasks

These scripts are also available as VS Code tasks:

- `Validate Environment Variables`
- `Fix Security Issues`
- `Commit VS Code Config`
- `Verify GitHub Setup`

## Dependencies

- PowerShell 7.0+
- Modules from parent directory:
  - Common.psm1
  - Environment.psm1
  - Security.psm1
  - Git.psm1
  - VSCode.psm1
