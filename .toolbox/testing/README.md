# Toolbox Testing Tools

This directory contains tools for testing and validating the AutoGen toolbox environment.

## Available Tools

- `Test-ToolboxEnvironment.ps1` - Tests the toolbox environment to ensure all tools are properly configured and functioning

## Usage

Run all scripts from the repository root directory:

```powershell
# Test the toolbox environment
.\.toolbox\testing\Test-ToolboxEnvironment.ps1

# Test with detailed output
.\.toolbox\testing\Test-ToolboxEnvironment.ps1 -Detailed

# Test and fix issues
.\.toolbox\testing\Test-ToolboxEnvironment.ps1 -Fix
```

## Test Coverage

The testing tools cover:

1. Individual script validation
   - Checking for hardcoded paths
   - Verifying proper documentation
   - Ensuring scripts have proper parameter blocks
   - Syntax checking

2. Integration testing
   - Documentation generation
   - VS Code task integration
   - Toolbox catalog consistency

## Adding New Tests

When adding a new test:

1. Add it to the `Test-ToolboxEnvironment.ps1` script
2. Ensure it handles the `-Detailed` and `-Fix` parameters appropriately
3. Update this README with the new test coverage
