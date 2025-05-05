# Reset-VSCodeEnvironment.ps1
# Script to reset VS Code extension settings and refresh the environment

Write-Host "Resetting VS Code environment..." -ForegroundColor Cyan

# Ensure the virtual environment is up to date
if (Test-Path -Path ".\.venv\Scripts\Activate.ps1") {
    Write-Host "Activating virtual environment..." -ForegroundColor Green
    & .\.venv\Scripts\Activate.ps1
} else {
    Write-Host "Creating a new virtual environment..." -ForegroundColor Yellow
    python -m venv .venv
    & .\.venv\Scripts\Activate.ps1
}

# Install or update required packages
Write-Host "Installing/updating required packages..." -ForegroundColor Green
pip install --upgrade pip
pip install ruff==0.5.3 mypy==1.13.0 pytest pytest-asyncio pytest-cov pytest-xdist

# Clear any cached data
if (Test-Path -Path "$env:APPDATA\Code\User\workspaceStorage") {
    Write-Host "Clearing extension caches (close VS Code if open)..." -ForegroundColor Yellow
    Get-ChildItem -Path "$env:APPDATA\Code\User\workspaceStorage\*\matangover.mypy" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$env:APPDATA\Code\User\workspaceStorage\*\charliermarsh.ruff" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# Create a .env file for VS Code to use the correct python path
$pythonPath = (& python -c "import sys; print(sys.executable)").Replace("\", "/")
Set-Content -Path ".\.env" -Value "PYTHONPATH=$pythonPath"

Write-Host "Environment reset complete!" -ForegroundColor Cyan
Write-Host "Please reload VS Code window now." -ForegroundColor Green
