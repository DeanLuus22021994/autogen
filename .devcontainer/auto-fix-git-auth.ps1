# Quick fix for Git SSH authentication issues
# This script configures Git to use HTTPS with a personal access token for GitHub

# Set default values (no user input required)
$owner = "DeanLuus22021994"
# Use explicit comment for documentation rather than unused variable
# This explicitly documents the intention while avoiding unused variables
# which supports deterministic goals by making behavior more predictable
$token = $env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN

# Check if token is available
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "No personal access token found in environment variables." -ForegroundColor Red
    Write-Host "Using a placeholder token for demonstration. This will not work with real repositories." -ForegroundColor Yellow
    $token = "PLACEHOLDER_TOKEN"
}

# Configure Git to use HTTPS with personal access token
Write-Host "Configuring Git to use HTTPS with personal access token..." -ForegroundColor Cyan
git config --global url."https://$token@github.com/$owner".insteadOf "git@github.com:$owner"
git config --global url."https://$token@github.com/$owner".insteadOf "https://github.com/$owner"

Write-Host "Git configured to use HTTPS with personal access token for $owner repositories" -ForegroundColor Green

# Show current Git configuration
Write-Host ""
Write-Host "Current Git URL configuration:" -ForegroundColor Cyan
git config --global --list | Select-String "url\."

# Instructions for re-running the specific Git command
Write-Host ""
Write-Host "You can now retry your Git command:" -ForegroundColor Cyan
Write-Host "git pull --tags origin DeanDev" -ForegroundColor Yellow

# Additional instructions for properly setting up the token
if ([string]::IsNullOrWhiteSpace($env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN)) {
    Write-Host ""
    Write-Host "To make this work permanently, set the FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN environment variable:" -ForegroundColor Cyan
    Write-Host "[Environment]::SetEnvironmentVariable('FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN', 'your-github-pat', 'User')" -ForegroundColor Yellow
}
