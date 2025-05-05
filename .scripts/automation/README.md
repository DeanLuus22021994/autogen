# AutoGen Automation System

## Overview

This repository contains a comprehensive automation system for the AutoGen project, designed to streamline development workflows, enhance security, and provide consistent environment configuration.

## Architecture

The automation system uses a modular PowerShell-based architecture:

```
.scripts/
  └── automation/
      └── github/
          ├── common/          # Common utility functions
          ├── config/          # Configuration management
          ├── security/        # Security scanning and validation
          ├── validation/      # Environment validation
          ├── orchestration/   # Main entry point scripts
          ├── Common.psm1      # Common module
          ├── Environment.psm1 # Environment variable management
          ├── Security.psm1    # Security utilities
          ├── Git.psm1         # Git operations
          └── VSCode.psm1      # VS Code integration
```

## Core Features

- **Environment Validation**: Ensures all required variables and tools are properly configured
- **Security Scanning**: Detects exposed tokens and secrets in repository files
- **Git Management**: Handles secure Git operations and repository configuration
- **VS Code Integration**: Manages VS Code settings and configurations securely
- **Orchestration**: Provides simple entry points for common development tasks

## Getting Started

1. Clone the repository
2. Set up required environment variables (see docs/ENVIRONMENT_SETUP.md)
3. Run the validation script:

```powershell
pwsh -File .\.scripts\automation\github\orchestration\Validate-Environment.ps1
```

4. Use VS Code tasks to access common operations:
   - `Validate Environment Variables`
   - `Fix Security Issues`
   - `Commit VS Code Config`
   - `Verify GitHub Setup`

## Requirements

- PowerShell 7.0+
- Git
- VS Code (recommended)
- Python 3.8+ (for Python development)

## Documentation

Comprehensive documentation is available in:
- README.md files in each module directory
- Function documentation in module files
- docs/ENVIRONMENT_SETUP.md

## Security Features

- Token pattern detection for common API keys and secrets
- Secure handling of environment variables
- Protection against accidental secret commits
- GitHub workflow integration for CI validation

## Future Enhancements

- Advanced integration testing
- Additional DevOps pipeline automation
- Container-based development environment support
- Cross-platform testing improvements

## Contributing

When contributing to this automation system:

1. Follow PowerShell best practices
2. Maintain the modular architecture
3. Add comprehensive documentation
4. Include proper error handling
5. Test thoroughly on multiple platforms

## License

This project is licensed under the same terms as the main AutoGen project.
