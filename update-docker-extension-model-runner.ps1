# Update Docker Extension for Model Runner Support
# This script updates the Docker extension to version 2.0.0+ to support Docker Model Runner

# Check if running elevated
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "For best results, please run this script as Administrator" -ForegroundColor Yellow
}

# Uninstall the old Docker extension
$vsCodeExtDir = "$env:USERPROFILE\.vscode\extensions"
$dockerExtensions = Get-ChildItem -Path $vsCodeExtDir -Directory -Filter "ms-azuretools.vscode-docker*"

if ($dockerExtensions.Count -gt 0) {
    Write-Host "Found Docker extension installations:" -ForegroundColor Cyan
    $dockerExtensions | ForEach-Object {
        Write-Host "- $($_.Name)" -ForegroundColor White
    }

    foreach ($extension in $dockerExtensions) {
        $version = ($extension.Name -split "-")[-1]
        Write-Host "Removing Docker extension version $version..." -ForegroundColor Yellow
        Remove-Item -Path $extension.FullName -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $extension.FullName) {
            Write-Host "Failed to remove extension at $($extension.FullName)" -ForegroundColor Red
            Write-Host "Please close VS Code and try again" -ForegroundColor Yellow
        } else {
            Write-Host "Successfully removed extension $($extension.Name)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "No Docker extension found in the default location." -ForegroundColor Yellow
}

# Install the latest Docker extension that supports Model Runner
Write-Host "`nInstalling latest Docker extension with Model Runner support:" -ForegroundColor Cyan
Write-Host "1. Open VS Code" -ForegroundColor White
Write-Host "2. Go to the Extensions view (Ctrl+Shift+X)" -ForegroundColor White
Write-Host "3. Search for 'Docker'" -ForegroundColor White
Write-Host "4. Find the extension by Microsoft (ms-azuretools.vscode-docker)" -ForegroundColor White
Write-Host "5. Click Install or Update" -ForegroundColor White
Write-Host "`nAlternatively, you can run this command in your terminal:" -ForegroundColor Cyan
Write-Host "code --install-extension ms-azuretools.vscode-docker" -ForegroundColor White

# Verify Docker Model Runner support
Write-Host "`nAfter installation, enable Docker Model Runner in Docker Desktop:" -ForegroundColor Cyan
Write-Host "1. Open Docker Desktop" -ForegroundColor White
Write-Host "2. Go to Settings > Features in development > Beta" -ForegroundColor White
Write-Host "3. Enable 'Docker Model Runner'" -ForegroundColor White
Write-Host "4. Click 'Apply & restart'" -ForegroundColor White

# Test Docker Model Runner availability
Write-Host "`nTo verify Docker Model Runner is working, run this command:" -ForegroundColor Cyan
Write-Host "docker model list" -ForegroundColor White
Write-Host "`nIf no models are shown, you can pull a model with:" -ForegroundColor White
Write-Host "docker model pull ai/mistral" -ForegroundColor White

Write-Host "`nFor more information on Docker Model Runner integration, see:" -ForegroundColor Green
Write-Host ".github/copilot/workflows/docker-model-integration.md" -ForegroundColor White
