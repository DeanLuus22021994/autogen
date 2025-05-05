# Verify-GitHubSetup.ps1
# Verifies and configures GitHub repository settings

#Requires -Version 7.0

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
$modulesPath = $rootPath

# Import all modules
Import-Module "$modulesPath\Common.psm1" -Force
Import-Module "$modulesPath\Environment.psm1" -Force
Import-Module "$modulesPath\Git.psm1" -Force

function Verify-GitHubSetup {
    Write-Host ""
    Write-SectionHeader "AutoGen GitHub Repository Verification"
    Write-StatusMessage "Verifying GitHub repository setup..." "Info" 0

    # Check if required environment variables are set
    $requiredVariables = @(
        "FORK_AUTOGEN_OWNER",
        "FORK_AUTOGEN_REPO",
        "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN"
    )

    $envStatus = Test-EnvironmentVariables -RequiredVariables $requiredVariables

    if (-not $envStatus) {
        Write-StatusMessage "Missing required environment variables" "Error" 0
        Write-StatusMessage "Please set the required variables and try again" "Error" 0
        return
    }

    # Get current Git configuration
    Write-StatusMessage "Checking Git configuration..." "Info" 0

    $repoUrl = git config --get remote.origin.url
    $currentBranch = git rev-parse --abbrev-ref HEAD

    # Parse current repository details
    $currentOwner = ""
    $currentRepo = ""

    if ($repoUrl -match "github.com[:/]([^/]+)/([^/\.]+)(\.git)?") {
        $currentOwner = $Matches[1]
        $currentRepo = $Matches[2]

        Write-StatusMessage "Current repository: $currentOwner/$currentRepo" "Info" 1
    }
    else {
        Write-StatusMessage "Unable to parse current repository URL: $repoUrl" "Warning" 1
    }

    # Check if repository matches environment variables
    if ($currentOwner -ne $env:FORK_AUTOGEN_OWNER -or $currentRepo -ne $env:FORK_AUTOGEN_REPO) {
        Write-StatusMessage "Repository configuration doesn't match environment variables" "Warning" 0
        Write-StatusMessage "Environment variables: $env:FORK_AUTOGEN_OWNER/$env:FORK_AUTOGEN_REPO" "Info" 1

        $response = Read-Host "Update Git remotes to match environment variables? (Y/N)"
        if ($response -eq "Y" -or $response -eq "y") {
            # Configure remotes based on environment variables
            $newRepoUrl = "https://github.com/$($env:FORK_AUTOGEN_OWNER)/$($env:FORK_AUTOGEN_REPO).git"

            # Check if origin exists
            $originExists = git remote get-url origin 2>&1
            if ($LASTEXITCODE -eq 0) {
                git remote set-url origin $newRepoUrl
                Write-StatusMessage "Updated origin remote to: $newRepoUrl" "Success" 1
            }
            else {
                git remote add origin $newRepoUrl
                Write-StatusMessage "Added origin remote: $newRepoUrl" "Success" 1
            }

            # Configure upstream to the main Microsoft repo
            $upstreamExists = git remote get-url upstream 2>&1
            if ($LASTEXITCODE -eq 0) {
                git remote set-url upstream "https://github.com/microsoft/autogen.git"
                Write-StatusMessage "Updated upstream remote to microsoft/autogen" "Success" 1
            }
            else {
                git remote add upstream "https://github.com/microsoft/autogen.git"
                Write-StatusMessage "Added upstream remote: microsoft/autogen" "Success" 1
            }
        }
    }
    else {
        Write-StatusMessage "Repository configuration matches environment variables" "Success" 0
    }

    # Check if user git config is set
    $gitUser = git config --get user.name
    $gitEmail = git config --get user.email

    if (-not $gitUser -or -not $gitEmail) {
        Write-StatusMessage "Git user configuration is incomplete" "Warning" 0

        $response = Read-Host "Would you like to configure Git user settings? (Y/N)"
        if ($response -eq "Y" -or $response -eq "y") {
            $userName = Read-Host "Enter your Git user name (or press Enter to use '$env:FORK_AUTOGEN_OWNER')"
            if ([string]::IsNullOrWhiteSpace($userName)) {
                $userName = $env:FORK_AUTOGEN_OWNER
            }

            $userEmail = Read-Host "Enter your Git email (or press Enter to use GitHub-provided email)"

            Initialize-GitConfig -UserName $userName -Email $userEmail
        }
    }
    else {
        Write-StatusMessage "Git user configured as: $gitUser <$gitEmail>" "Success" 0
    }

    # Verify GitHub API access
    Write-StatusMessage "Verifying GitHub API access..." "Info" 0

    try {
        $headers = @{
            Authorization = "token $env:FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN"
            Accept = "application/vnd.github.v3+json"
        }

        $response = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get

        Write-StatusMessage "Successfully authenticated with GitHub API as: $($response.login)" "Success" 0

        # Check repository access
        $repoEndpoint = "https://api.github.com/repos/$($env:FORK_AUTOGEN_OWNER)/$($env:FORK_AUTOGEN_REPO)"
        $repoResponse = Invoke-RestMethod -Uri $repoEndpoint -Headers $headers -Method Get -ErrorAction SilentlyContinue

        if ($repoResponse.id) {
            Write-StatusMessage "Verified access to repository: $($repoResponse.full_name)" "Success" 1
            Write-StatusMessage "Repository visibility: $($repoResponse.visibility)" "Info" 1

            if ($repoResponse.fork) {
                Write-StatusMessage "This is a fork of: $($repoResponse.parent.full_name)" "Info" 1
            }
        }
    }
    catch {
        Write-StatusMessage "Failed to authenticate with GitHub API" "Error" 0
        Write-StatusMessage "Error: $($_.Exception.Message)" "Error" 1
        Write-StatusMessage "Please check your FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN environment variable" "Warning" 1
    }

    # Final output
    Write-Host ""
    Write-StatusMessage "GitHub setup verification completed" "Success" 0
    Write-Host ""
}

# Run the verification process
Verify-GitHubSetup
