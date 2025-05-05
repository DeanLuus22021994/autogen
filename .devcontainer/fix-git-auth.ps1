# This script fixes Git authentication issues using environment variables

Write-Host "Setting up Git authentication for AutoGen repository..." -ForegroundColor Cyan

# Check if environment variables are set
$token = [Environment]::GetEnvironmentVariable("FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN", "Process")
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "Error: FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN is not set." -ForegroundColor Red
    Write-Host "Please run the setup-environment.ps1 script or set this environment variable manually."
    exit 1
}

$owner = [Environment]::GetEnvironmentVariable("FORK_AUTOGEN_OWNER", "Process")
if ([string]::IsNullOrWhiteSpace($owner)) {
    Write-Host "Error: FORK_AUTOGEN_OWNER is not set." -ForegroundColor Red
    Write-Host "Please run the setup-environment.ps1 script or set this environment variable manually."
    exit 1
}

# Configure Git to use HTTPS with personal access token
git config --global url."https://$token@github.com/$owner".insteadOf "git@github.com:$owner"
git config --global url."https://$token@github.com/$owner".insteadOf "https://github.com/$owner"

Write-Host "Git configured to use HTTPS with personal access token for $owner repositories" -ForegroundColor Green

# Verify the connection
Write-Host "Testing GitHub connection..." -ForegroundColor Cyan
$repoPath = [Environment]::GetEnvironmentVariable("REPO_PATH", "Process")
if ([string]::IsNullOrWhiteSpace($repoPath)) {
    $repoPath = "autogen"
}

$testResult = git ls-remote "https://$token@github.com/$owner/$repoPath.git" HEAD 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "GitHub connection successful!" -ForegroundColor Green
} else {
    Write-Host "GitHub connection failed. Please check your credentials." -ForegroundColor Red
    Write-Host $testResult -ForegroundColor Red
}
