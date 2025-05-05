# .github/linting/Initialize-MarkdownLinting.ps1
# Main entry point for markdown linting setup

param(
    [switch]$Force,
    [switch]$Validate,
    [switch]$Help,
    [switch]$CleanupRoot  # Parameter to remove root files
)

using namespace System.IO
using namespace System.Management.Automation

# Import helper module
$scriptPath = $PSScriptRoot
$helperModulePath = Join-Path -Path $scriptPath -ChildPath "MarkdownLintHelpers.psm1"
Import-Module $helperModulePath -Force -ErrorAction Stop

# Show help if requested
if ($Help) {
    Show-MarkdownLintHelp
    exit 0
}

# Ensure we're in the repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
    Write-Host "Working in repository root: $repoRoot" -ForegroundColor Green
} else {
    Write-Host "Error: Not in a git repository." -ForegroundColor Red
    exit 1
}

# Check prerequisites
$prerequisites = @{
    "Node.js" = { Get-Command node -ErrorAction SilentlyContinue }
    "npm"     = { Get-Command npm -ErrorAction SilentlyContinue }
    "npx"     = { Get-Command npx -ErrorAction SilentlyContinue }
}

$missingPrerequisites = $prerequisites.GetEnumerator() |
    Where-Object { -not (& $_.Value) } |
    Select-Object -ExpandProperty Key

if ($missingPrerequisites.Count -gt 0) {
    Write-Warning "Missing prerequisites: $($missingPrerequisites -join ', ')"
    Write-Warning "Some functionality may not work properly without these tools."

    if (-not $Force -and -not (Get-Confirmation "Continue anyway?")) {
        Write-Host "Operation canceled." -ForegroundColor Red
        exit 1
    }
}

# Create linting directory
$lintingDir = ".github/linting"
if (-not (Test-Path $lintingDir)) {
    Write-Host "Creating $lintingDir directory..." -ForegroundColor Yellow
    New-Item -Path $lintingDir -ItemType Directory -Force | Out-Null
    Write-Host "Directory created successfully." -ForegroundColor Green
} else {
    Write-Host "Directory $lintingDir already exists." -ForegroundColor Green
}

# Create all configuration files
New-MarkdownLintingFiles -Force:$Force

# Perform additional steps
if ($CleanupRoot) {
    Invoke-MarkdownLintingCleanup
}

# Run validation if requested
if ($Validate) {
    Write-Host "`nRunning validation checks..." -ForegroundColor Cyan
    Invoke-LintValidation
}

# Final completion message with summary
Write-Host "`n=== Markdown Linting Configuration Setup Complete ===" -ForegroundColor Green
Write-Host "Setup has completed the following tasks:" -ForegroundColor Cyan
Write-Host "✅ Created configuration files in .github/linting" -ForegroundColor Green
Write-Host "✅ Created workflow file for GitHub Actions" -ForegroundColor Green
if ($CleanupRoot) {
    Write-Host "✅ Created redirects from root to .github/linting" -ForegroundColor Green
} else {
    Write-Host "✅ Synced configuration files to repository root" -ForegroundColor Green
}
if ($Validate) {
    Write-Host "✅ Validated the configuration" -ForegroundColor Green
}

Write-Host "`nTo run linting on your markdown files:" -ForegroundColor Yellow
Write-Host "  pwsh .github/linting/Invoke-MarkdownLint.ps1" -ForegroundColor White

Write-Host "`nAll tasks completed successfully." -ForegroundColor Green