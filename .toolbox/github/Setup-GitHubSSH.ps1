$sshDirectory = "$env:USERPROFILE\.ssh"
$keyFile = "$sshDirectory\id_ed25519"
$pubKeyFile = "$keyFile.pub"
$configFile = "$sshDirectory\config"

# Create .ssh directory if it doesn't exist
if (-not (Test-Path $sshDirectory)) {
    Write-Host "Creating .ssh directory..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $sshDirectory -Force | Out-Null
}

# Check if key already exists
if (-not (Test-Path $keyFile)) {
    Write-Host "SSH key doesn't exist, generating new key..." -ForegroundColor Cyan

    # Generate SSH key (non-interactive)
    & ssh-keygen -t ed25519 -f $keyFile -N '""' -C "autogen-github-access"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to generate SSH key. Please check if OpenSSH is installed." -ForegroundColor Red
        exit 1
    }

    Write-Host "SSH key generated successfully!" -ForegroundColor Green
} else {
    Write-Host "SSH key already exists, reusing existing key." -ForegroundColor Yellow
}

# Create or update SSH config file
$configContent = @"
Host github.com
    HostName github.com
    User git
    IdentityFile $keyFile
    PreferredAuthentications publickey
"@

Set-Content -Path $configFile -Value $configContent -Force
Write-Host "SSH config file created/updated." -ForegroundColor Green

# Start the SSH agent
Write-Host "Starting SSH agent..." -ForegroundColor Cyan
Start-Service ssh-agent -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) {
    Write-Host "SSH agent service couldn't be started. Adding key manually." -ForegroundColor Yellow
    & ssh-agent
}

# Add the key to the agent
Write-Host "Adding SSH key to agent..." -ForegroundColor Cyan
& ssh-add $keyFile

Write-Host "`nYour public key is:" -ForegroundColor Cyan
Get-Content $pubKeyFile

Write-Host "`n========================================================" -ForegroundColor Yellow
Write-Host "IMPORTANT: You need to add this public key to your GitHub account!" -ForegroundColor Yellow
Write-Host "1. Copy the public key shown above" -ForegroundColor Yellow
Write-Host "2. Go to https://github.com/settings/keys" -ForegroundColor Yellow
Write-Host "3. Click 'New SSH key'" -ForegroundColor Yellow
Write-Host "4. Paste the key and give it a title" -ForegroundColor Yellow
Write-Host "5. Click 'Add SSH key'" -ForegroundColor Yellow
Write-Host "========================================================`n" -ForegroundColor Yellow

Write-Host "Testing connection to GitHub..." -ForegroundColor Cyan
$testResult = & ssh -T -o "StrictHostKeyChecking=no" git@github.com 2>&1
Write-Host $testResult

if ($testResult -match "successfully authenticated") {
    Write-Host "`nSuccess! You should now be able to push/pull from GitHub via SSH." -ForegroundColor Green
} else {
    Write-Host "`nConnection test failed. Make sure you've added the public key to your GitHub account." -ForegroundColor Yellow

    # Try changing remote URL to HTTPS as backup
    Write-Host "Attempting to change remote URL to HTTPS as a temporary solution..." -ForegroundColor Cyan

    # Get current remote URL
    $currentRemote = & git config --get remote.origin.url

    # If it's an SSH URL, convert to HTTPS
    if ($currentRemote -match "git@github.com:(.+)") {
        $repoPath = $matches[1]
        $httpsUrl = "https://github.com/$repoPath"

        # Update the remote URL
        & git remote set-url origin $httpsUrl
        Write-Host "Remote URL changed to HTTPS: $httpsUrl" -ForegroundColor Green
        Write-Host "You'll need to provide your GitHub username and password/token when pushing/pulling." -ForegroundColor Yellow
    }
}
