# Update Docker Extension Script
# This script will help uninstall the old Docker extension and provide instructions for installing the new one

# Uninstall the old Docker extension
$oldExtensionPath = "$env:USERPROFILE\.vscode\extensions\ms-azuretools.vscode-docker-1.29.6"
if (Test-Path $oldExtensionPath) {
    Write-Host "Removing old Docker extension from $oldExtensionPath..." -ForegroundColor Yellow
    Remove-Item -Path $oldExtensionPath -Recurse -Force
    Write-Host "Old Docker extension removed successfully!" -ForegroundColor Green
} else {
    Write-Host "Old Docker extension not found at the expected location." -ForegroundColor Yellow
}

# Instructions for installing the new Docker extension
Write-Host "`nTo install the latest Docker extension:" -ForegroundColor Cyan
Write-Host "1. Open VS Code" -ForegroundColor White
Write-Host "2. Go to the Extensions view (Ctrl+Shift+X)" -ForegroundColor White
Write-Host "3. Search for 'Docker'" -ForegroundColor White
Write-Host "4. Find the extension by Microsoft (ms-azuretools.vscode-docker)" -ForegroundColor White
Write-Host "5. Click Install or Update" -ForegroundColor White
Write-Host "`nAlternatively, you can run the following command in VS Code's Command Palette (Ctrl+Shift+P):" -ForegroundColor Cyan
Write-Host "> Extensions: Install Extension" -ForegroundColor White
Write-Host "Then type 'Docker' and select the Microsoft Docker extension" -ForegroundColor White

Write-Host "`nAfter installation, restart VS Code for the changes to take effect." -ForegroundColor Green
