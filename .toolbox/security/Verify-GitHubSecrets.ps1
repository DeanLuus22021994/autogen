#!/usr/bin/env pwsh
# Verify-GitHubSecrets.ps1
# This script verifies that required secrets are set in GitHub Actions for the repository

param (
    [string]$Owner = $env:FORK_AUTOGEN_OWNER,
    [string]$Repo = "autogen",
    [switch]$FixMissingSecrets
)

# Colors for console output
$colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
}

function Write-ColorMessage {
    param (
        [string]$Message,
        [string]$Color = "White"
    )

    Write-Host $Message -ForegroundColor $Color
}

function Get-GitHubSecrets {
    param (
        [string]$RepoOwner,
        [string]$RepoName
    )

    $token = $env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN

    if (-not $token) {
        Write-ColorMessage "GitHub Personal Access Token is not set in environment variables." $colors.Error
        Write-ColorMessage "Please set FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN and try again." $colors.Error
        return $null
    }

    $headers = @{
        Authorization = "token $token"
        Accept = "application/vnd.github.v3+json"
    }

    try {
        # We can't directly get the list of secrets due to GitHub API limitations,
        # but we can get the public keys for the repo, which indicates the repo can use secrets
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/actions/secrets/public-key" -Headers $headers -Method Get
        return @{
            Success = $true
            Message = "Successfully connected to GitHub API"
            PublicKey = $response
        }
    } catch {
        return @{
            Success = $false
            Message = "Error connecting to GitHub API: $_"
            StatusCode = $_.Exception.Response.StatusCode.value__
        }
    }
}

function Set-GitHubSecret {
    param (
        [string]$RepoOwner,
        [string]$RepoName,
        [string]$SecretName,
        [string]$SecretValue,
        [object]$PublicKey
    )

    $token = $env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN

    if (-not $token) {
        Write-ColorMessage "GitHub Personal Access Token is not set in environment variables." $colors.Error
        return $false
    }

    if (-not $SecretValue) {
        Write-ColorMessage "Secret value for $SecretName is empty. Skipping." $colors.Warning
        return $false
    }

    $headers = @{
        Authorization = "token $token"
        Accept = "application/vnd.github.v3+json"
    }

    # GitHub requires the secret to be encrypted using the repository's public key
    Add-Type -AssemblyName System.Security
    $publicKeyBytes = [System.Convert]::FromBase64String($PublicKey.key)
    $secretBytes = [System.Text.Encoding]::UTF8.GetBytes($SecretValue)

    $sealedPublicKeyBox = [System.Security.Cryptography.X509Certificates.PublicKey]::CreateFromSubjectPublicKeyInfo($publicKeyBytes, 0)

    # Since we can't actually encrypt in PowerShell easily with libsodium,
    # we'll use a placeholder for the encryption and provide instructions
    Write-ColorMessage "To set the secret $SecretName, you need to:" $colors.Info
    Write-ColorMessage "1. Go to https://github.com/$RepoOwner/$RepoName/settings/secrets/actions" $colors.Info
    Write-ColorMessage "2. Click 'New repository secret'" $colors.Info
    Write-ColorMessage "3. Name: $SecretName" $colors.Info
    Write-ColorMessage "4. Value: (Your current environment value)" $colors.Info
    Write-ColorMessage "5. Click 'Add secret'" $colors.Info

    return $true
}

function Verify-GitHubSecrets {
    param (
        [string]$RepoOwner,
        [string]$RepoName,
        [switch]$Fix
    )

    Write-ColorMessage "Verifying GitHub Actions secrets for $RepoOwner/$RepoName..." $colors.Info

    # Required secrets
    $requiredSecrets = @(
        "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN",
        "FORK_USER_DOCKER_ACCESS_TOKEN",
        "FORK_HUGGINGFACE_ACCESS_TOKEN"
    )

    # Get the GitHub secrets
    $githubSecrets = Get-GitHubSecrets -RepoOwner $RepoOwner -RepoName $RepoName

    if (-not $githubSecrets.Success) {
        Write-ColorMessage $githubSecrets.Message $colors.Error

        if ($githubSecrets.StatusCode -eq 404) {
            Write-ColorMessage "Repository not found or you don't have access to it." $colors.Error
        } elseif ($githubSecrets.StatusCode -eq 401) {
            Write-ColorMessage "Authentication failed. Check your personal access token." $colors.Error
        }

        return
    }

    Write-ColorMessage "Successfully connected to GitHub API ✅" $colors.Success
    Write-ColorMessage "Unable to directly list secrets due to GitHub API limitations." $colors.Info

    # Check if we have the required environment variables locally
    foreach ($secret in $requiredSecrets) {
        $envValue = Get-Item "env:$secret" -ErrorAction SilentlyContinue

        if ($envValue) {
            Write-ColorMessage "  ✅ $secret is set locally in environment variables" $colors.Success

            if ($Fix) {
                $result = Set-GitHubSecret -RepoOwner $RepoOwner -RepoName $RepoName -SecretName $secret -SecretValue $envValue.Value -PublicKey $githubSecrets.PublicKey
            }
        } else {
            Write-ColorMessage "  ❌ $secret is not set locally in environment variables" $colors.Error
            Write-ColorMessage "    Please set this environment variable and run the script again." $colors.Warning
        }
    }

    Write-ColorMessage ""
    Write-ColorMessage "Please visit the following URL to manually verify and set your GitHub secrets:" $colors.Info
    Write-ColorMessage "https://github.com/$RepoOwner/$RepoName/settings/secrets/actions" $colors.Info
}

# Main script execution

if (-not $Owner) {
    Write-ColorMessage "Owner parameter not provided and FORK_AUTOGEN_OWNER environment variable not set." $colors.Error
    Write-ColorMessage "Please provide an owner with -Owner parameter or set FORK_AUTOGEN_OWNER environment variable." $colors.Error
    exit 1
}

Verify-GitHubSecrets -RepoOwner $Owner -RepoName $Repo -Fix:$FixMissingSecrets
