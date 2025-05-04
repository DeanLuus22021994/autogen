# Load environment variables from .env file
function Import-DotEnv {
    param(
        [string]$envFile = "$PSScriptRoot/.env"
    )

    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if (!$_.StartsWith("#") -and $_.Contains("=")) {
                $key, $value = $_ -split '=', 2
                $key = $key.Trim()
                $value = $value.Trim().Trim('"')
                if ($value) {
                    [Environment]::SetEnvironmentVariable($key, $value, "Process")
                }
            }
        }
    }
    else {
        Write-Warning "Environment file $envFile not found."
    }
}

# Import environment variables
Import-DotEnv

# Configure Git to use HTTPS with personal access token
$token = [Environment]::GetEnvironmentVariable("FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN", "Process")
$owner = [Environment]::GetEnvironmentVariable("FORK_AUTOGEN_OWNER", "Process")
$repoPath = [Environment]::GetEnvironmentVariable("REPO_PATH", "Process")

if ($token) {
    # Configure Git to use HTTPS with the token
    git config --global url."https://$token@github.com/$owner".insteadOf "git@github.com:$owner"
    git config --global url."https://$token@github.com/$owner".insteadOf "https://github.com/$owner"

    Write-Host "Git configured to use HTTPS with personal access token for $owner repositories"
}
else {
    Write-Warning "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN is not set. You may encounter authentication issues."
}

# Configure Git user information if needed
$gitEmail = git config --global user.email
if (-not $gitEmail) {
    Write-Host "Setting up Git user email and name..."
    git config --global user.email "github-actions@github.com"
    git config --global user.name "GitHub Actions"
}

# Verify the connection
Write-Host "Testing GitHub connection..."
$testResult = git ls-remote "https://github.com/$owner/$repoPath.git" HEAD
if ($LASTEXITCODE -eq 0) {
    Write-Host "GitHub connection successful!"
}
else {
    Write-Host "GitHub connection failed. Please check your credentials."
}