# This script helps set up the required environment variables for AutoGen development

# Function to test input is not empty
function Test-InputNotEmpty {
    param(
        [string]$inputValue,
        [string]$message
    )

    if ([string]::IsNullOrWhiteSpace($inputValue)) {
        Write-Host $message -ForegroundColor Red
        return $false
    }
    return $true
}

# Function to set an environment variable for the current user
function Set-UserEnvironmentVariable {
    param(
        [string]$name,
        [string]$value
    )

    [Environment]::SetEnvironmentVariable($name, $value, "User")
    [Environment]::SetEnvironmentVariable($name, $value, "Process")
    Write-Host "Environment variable $name has been set." -ForegroundColor Green
}

Write-Host "AutoGen Environment Setup" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host "This script will set up the required environment variables for working with AutoGen."
Write-Host "Leave a field blank to skip setting that variable." -ForegroundColor Yellow
Write-Host ""

# Get GitHub username
$githubUsername = Read-Host "Enter your GitHub username (e.g., DeanLuus22021994)"
if (Test-InputNotEmpty $githubUsername "GitHub username is required.") {
    Set-UserEnvironmentVariable "FORK_AUTOGEN_OWNER" $githubUsername
}

# Get GitHub personal access token
$githubToken = Read-Host "Enter your GitHub Personal Access Token (PAT)" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($githubToken)
$tokenValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

if (Test-InputNotEmpty $tokenValue "GitHub Personal Access Token is required.") {
    Set-UserEnvironmentVariable "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN" $tokenValue
}

# Get Docker username
$dockerUsername = Read-Host "Enter your Docker Hub username"
if (Test-InputNotEmpty $dockerUsername "Docker Hub username is required.") {
    Set-UserEnvironmentVariable "FORK_AUTOGEN_USER_DOCKER_USERNAME" $dockerUsername
}

# Get Docker access token
$dockerToken = Read-Host "Enter your Docker Hub access token" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($dockerToken)
$dockerTokenValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

if (Test-InputNotEmpty $dockerTokenValue "Docker Hub access token is required.") {
    Set-UserEnvironmentVariable "FORK_USER_DOCKER_ACCESS_TOKEN" $dockerTokenValue
}

# Get Hugging Face access token
$hfToken = Read-Host "Enter your Hugging Face access token" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($hfToken)
$hfTokenValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

if (Test-InputNotEmpty $hfTokenValue "Hugging Face access token is required.") {
    Set-UserEnvironmentVariable "FORK_HUGGINGFACE_ACCESS_TOKEN" $hfTokenValue
}

# Set repository path
Set-UserEnvironmentVariable "REPO_PATH" "autogen"

# Set repository URL
$repoUrl = "https://github.com/$githubUsername/autogen"
Set-UserEnvironmentVariable "FORK_AUTOGEN_SSH_REPO_URL" $repoUrl

Write-Host ""
Write-Host "Environment variables have been set successfully." -ForegroundColor Green
Write-Host "You may need to restart your terminal or IDE for the changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "Testing GitHub connectivity..." -ForegroundColor Cyan

# Test GitHub connectivity using the token
$testResult = git ls-remote "https://$tokenValue@github.com/$githubUsername/autogen.git" HEAD 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "GitHub connection successful!" -ForegroundColor Green
} else {
    Write-Host "GitHub connection failed. Please check your credentials." -ForegroundColor Red
    Write-Host $testResult -ForegroundColor Red
}
