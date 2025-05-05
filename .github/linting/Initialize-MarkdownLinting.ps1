# .github/linting/Initialize-MarkdownLinting.ps1
# Initialization script for markdown linting environment

using namespace System.IO
using namespace System.Management.Automation

<#
.SYNOPSIS
    Initializes the markdown linting environment for the repository.
.DESCRIPTION
    Sets up and configures the markdown linting tools and configurations
    required for consistent documentation standards.
.NOTES
    Version:        1.0
    Author:         AutoGen Project Team
    Creation Date:  2023-10-01
#>

# Script parameters
[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigurationPath = (Join-Path $PSScriptRoot ".markdownlint-cli2.jsonc"),

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$Verbose
)

# Import the helper module
$helperModulePath = Join-Path $PSScriptRoot "core\MarkdownLintUtilities.psm1"
if (Test-Path $helperModulePath) {
    Import-Module $helperModulePath -Force
} else {
    throw "Required module not found: $helperModulePath"
}

# Main execution logic
try {
    Write-Host "Initializing Markdown linting environment..." -ForegroundColor Cyan

    # Verify dependencies
    Assert-MarkdownLintDependencies

    # Initialize configuration
    Initialize-MarkdownLintConfiguration -ConfigPath $ConfigurationPath -Force:$Force

    # Register tasks with VS Code if available
    Register-MarkdownLintVSCodeTasks

    Write-Host "Markdown linting environment successfully initialized!" -ForegroundColor Green
} catch {
    Write-Host "Error initializing Markdown linting: $_" -ForegroundColor Red
    throw $_
}