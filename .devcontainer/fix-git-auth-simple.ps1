# Fix GitHub Authentication Issue
# This script configures Git to use HTTPS with a personal access token
# instead of SSH authentication

# Clear screen
Clear-Host

Write-Host "GitHub Authentication Fix" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host "This script will fix the 'Permission denied (publickey)' error by configuring Git"
Write-Host "to use HTTPS with a personal access token instead of SSH authentication."
Write-Host ""

# Get GitHub username
$owner = Read-Host "Enter your GitHub username (e.g., DeanLuus22021994)"
if ([string]::IsNullOrWhiteSpace($owner)) {
    Write-Host "GitHub username is required." -ForegroundColor Red
    exit 1
}

# Get GitHub personal access token
$secureToken = Read-Host "Enter your GitHub Personal Access Token (PAT)" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
$token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "GitHub Personal Access Token is required." -ForegroundColor Red
    exit 1
}

# Configure Git to use HTTPS with personal access token
Write-Host "Configuring Git to use HTTPS with personal access token..." -ForegroundColor Cyan

git config --global url."https://$token@github.com/$owner".insteadOf "git@github.com:$owner"
git config --global url."https://$token@github.com/$owner".insteadOf "https://github.com/$owner"

Write-Host "Git configured to use HTTPS with personal access token for $owner repositories" -ForegroundColor Green

# Test GitHub connection
Write-Host "Testing GitHub connection..." -ForegroundColor Cyan
$repo = "autogen"
$testResult = git ls-remote "https://$token@github.com/$owner/$repo.git" HEAD 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "GitHub connection successful!" -ForegroundColor Green
    $connectionSuccessful = $true
}
else {
    Write-Host "GitHub connection failed. Check your credentials." -ForegroundColor Red
    Write-Host $testResult
    $connectionSuccessful = $false
}

# Save environment variables if connection was successful
if ($connectionSuccessful) {
    $setEnvVars = Read-Host "Save these credentials as environment variables? (Y/n)"
    if ([string]::IsNullOrWhiteSpace($setEnvVars) -or $setEnvVars.ToLower() -eq "y") {
        [Environment]::SetEnvironmentVariable("FORK_AUTOGEN_OWNER", $owner, "User")
        [Environment]::SetEnvironmentVariable("FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN", $token, "User")
        [Environment]::SetEnvironmentVariable("REPO_PATH", $repo, "User")

        # Also set for current session
        [Environment]::SetEnvironmentVariable("FORK_AUTOGEN_OWNER", $owner, "Process")
        [Environment]::SetEnvironmentVariable("FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN", $token, "Process")
        [Environment]::SetEnvironmentVariable("REPO_PATH", $repo, "Process")

        Write-Host "Environment variables saved successfully." -ForegroundColor Green
    }

    # Test the specific Git command that failed
    $testCommand = Read-Host "Test 'git pull --tags origin DeanDev' now? (Y/n)"
    if ([string]::IsNullOrWhiteSpace($testCommand) -or $testCommand.ToLower() -eq "y") {
        Write-Host "Running: git pull --tags origin DeanDev" -ForegroundColor Cyan
        git pull --tags origin DeanDev
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Command successful!" -ForegroundColor Green
        }
        else {
            Write-Host "Command failed. Additional configuration may be needed." -ForegroundColor Red
        }
    }
}

# Show current Git configuration
Write-Host ""
Write-Host "Current Git URL configuration:" -ForegroundColor Cyan
git config --global --list | Select-String "url\."
