# Script to run markdown linting on the repository
param(
    [string]$ConfigPath = ".markdownlint-cli2.jsonc",
    [string]$TargetPath = ".github/**/*.md",
    [switch]$Fix,
    [switch]$Help
)

# Show help if requested
if ($Help) {
    Write-Host "Usage: .\run-markdown-lint.ps1 [-ConfigPath <path>] [-TargetPath <glob>] [-Fix] [-Help]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -ConfigPath <path>   Path to config file (default: .markdownlint-cli2.jsonc)"
    Write-Host "  -TargetPath <glob>   Glob pattern for files to lint (default: .github/**/*.md)"
    Write-Host "  -Fix                 Fix linting issues where possible"
    Write-Host "  -Help                Show this help message"
    Write-Host ""
    Write-Host "Related Scripts:"
    Write-Host "  .\run-lint-check.ps1        Validate the linting configuration"
    Write-Host "  .\sync-config.ps1           Sync linting config to root directory"
    Write-Host "  .\update-spell-checker.ps1  Update spell checker with linting terms"
    exit 0
}

# Ensure we're in the repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
}

# Check if config exists in current location
if (-not (Test-Path $ConfigPath)) {
    # Check if config exists in .github/linting
    $altConfigPath = Join-Path ".github" "linting" $ConfigPath
    if (Test-Path $altConfigPath) {
        Write-Host "Using configuration from $altConfigPath"
        $ConfigPath = $altConfigPath
    } else {
        Write-Host "Configuration file not found: $ConfigPath or $altConfigPath" -ForegroundColor Red
        exit 1
    }
}

# Run linting
Write-Host "Running markdown linting with config: $ConfigPath"
Write-Host "Target paths: $TargetPath"
Write-Host ""

if ($Fix) {
    & npx markdownlint-cli2 $TargetPath --config $ConfigPath --fix
} else {
    & npx markdownlint-cli2 $TargetPath --config $ConfigPath
}

# Return the exit code from markdownlint
exit $LASTEXITCODE
