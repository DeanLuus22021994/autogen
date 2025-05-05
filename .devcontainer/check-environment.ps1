# This script checks if all required environment variables are properly set

function Test-EnvVar {
    param(
        [string]$name
    )

    $value = [Environment]::GetEnvironmentVariable($name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Host "$name is not set" -ForegroundColor Red
        return $false
    } else {
        Write-Host "$name is set" -ForegroundColor Green
        return $true
    }
}

Write-Host "Checking AutoGen Environment Variables" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Check repository configuration
$repoPathSet = Test-EnvVar "REPO_PATH"

# Check GitHub configuration
$ownerSet = Test-EnvVar "FORK_AUTOGEN_OWNER"
# Using $repoUrlSet consistently throughout the script
$repoUrlSet = Test-EnvVar "FORK_AUTOGEN_SSH_REPO_URL"
$githubTokenSet = Test-EnvVar "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN"

# Check Docker configuration
$dockerUsernameSet = Test-EnvVar "FORK_AUTOGEN_USER_DOCKER_USERNAME"
$dockerTokenSet = Test-EnvVar "FORK_USER_DOCKER_ACCESS_TOKEN"

# Check API tokens
$hfTokenSet = Test-EnvVar "FORK_HUGGINGFACE_ACCESS_TOKEN"

Write-Host ""

# Test GitHub connectivity if token is set
if ($githubTokenSet -and $ownerSet -and $repoPathSet) {
    Write-Host "Testing GitHub connectivity..." -ForegroundColor Cyan
    $token = [Environment]::GetEnvironmentVariable("FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN", "Process")
    $owner = [Environment]::GetEnvironmentVariable("FORK_AUTOGEN_OWNER", "Process")
    $repoPath = [Environment]::GetEnvironmentVariable("REPO_PATH", "Process")

    $testOutput = git ls-remote "https://$token@github.com/$owner/$repoPath.git" HEAD 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "GitHub connection successful!" -ForegroundColor Green
    } else {
        Write-Host "GitHub connection failed. Please check your credentials." -ForegroundColor Red
        Write-Host $testOutput -ForegroundColor Red
    }
}

# Use repoUrlSet for authenticating private repositories if needed
if ($repoUrlSet) {
    $repoUrl = [Environment]::GetEnvironmentVariable("FORK_AUTOGEN_SSH_REPO_URL", "Process")
    Write-Host "Repository URL is configured: $repoUrl" -ForegroundColor Green
}

# Test Docker connectivity if token is set
if ($dockerTokenSet -and $dockerUsernameSet) {
    Write-Host "Testing Docker connectivity..." -ForegroundColor Cyan
    $token = [Environment]::GetEnvironmentVariable("FORK_USER_DOCKER_ACCESS_TOKEN", "Process")
    $username = [Environment]::GetEnvironmentVariable("FORK_AUTOGEN_USER_DOCKER_USERNAME", "Process")

    # Use Write-Output instead of echo alias
    $dockerLoginOutput = $token | docker login --username $username --password-stdin 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Docker login successful!" -ForegroundColor Green
        docker logout | Out-Null
    } else {
        Write-Host "Docker login failed. Please check your credentials." -ForegroundColor Red
        Write-Host $dockerLoginOutput -ForegroundColor Red
    }
}

# Validate Hugging Face token if configured
if ($hfTokenSet) {
    Write-Host "Hugging Face token is configured." -ForegroundColor Green
    $hfToken = [Environment]::GetEnvironmentVariable("FORK_HUGGINGFACE_ACCESS_TOKEN", "Process")
    if ($hfToken.Length -gt 0) {
        Write-Host "Hugging Face token appears valid (non-empty)." -ForegroundColor Green
    } else {
        Write-Host "Hugging Face token is empty. You may need to regenerate it." -ForegroundColor Red
    }
}
