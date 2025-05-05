# Commit-VSCodeConfig.ps1
# Safely commits VS Code configuration files after checking for security issues

#Requires -Version 7.0

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
$modulesPath = $rootPath

# Import all modules
Import-Module "$modulesPath\Common.psm1" -Force
Import-Module "$modulesPath\Security.psm1" -Force
Import-Module "$modulesPath\Git.psm1" -Force
Import-Module "$modulesPath\VSCode.psm1" -Force

function Commit-VSCodeConfig {
    Write-Host ""
    Write-SectionHeader "AutoGen VS Code Configuration Commit"
    Write-StatusMessage "Preparing to commit VS Code configuration files..." "Info" 0

    # Ensure VS Code directory exists
    $vscodePath = Join-Path $PWD ".vscode"
    if (-not (Test-Path $vscodePath)) {
        Write-StatusMessage "VS Code configuration directory not found" "Error" 0
        Write-StatusMessage "Run 'Initialize-VSCodeEnvironment' to create VS Code configuration" "Info" 0
        return
    }

    # Create base configuration if needed
    $response = Read-Host "Initialize or update VS Code configuration? (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        # Get the Python path
        $pythonPath = ""

        if (Test-Path ".venv\Scripts\python.exe") {
            $pythonPath = Join-Path $PWD ".venv\Scripts\python.exe"
            Write-StatusMessage "Using virtual environment Python: $pythonPath" "Info" 1
        }
        else {
            $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
            if ($pythonCommand) {
                $pythonPath = $pythonCommand.Path
                Write-StatusMessage "Using system Python: $pythonPath" "Info" 1
            }
            else {
                Write-StatusMessage "Python not found. VS Code configuration may be incomplete." "Warning" 1
            }
        }

        $result = Initialize-VSCodeEnvironment -PythonPath $pythonPath -UpdateWorkspaceSettings

        if (-not $result) {
            Write-StatusMessage "Failed to initialize VS Code environment" "Error" 0
            return
        }
    }

    # Check for security issues before committing
    Write-StatusMessage "Checking VS Code configuration for security issues..." "Info" 0
    $securityCheck = Test-VSCodeConfigSecurity

    if (-not $securityCheck) {
        Write-StatusMessage "Security issues found in VS Code configuration" "Error" 0

        $fixResponse = Read-Host "Would you like to fix these issues before committing? (Y/N)"
        if ($fixResponse -eq "Y" -or $fixResponse -eq "y") {
            $fixResult = Update-VSCodeConfigSecurely

            if (-not $fixResult) {
                Write-StatusMessage "Failed to fix security issues" "Error" 0
                return
            }

            # Check again after fixing
            $securityCheck = Test-VSCodeConfigSecurity
            if (-not $securityCheck) {
                Write-StatusMessage "Security issues persist after attempted fix" "Error" 0
                Write-StatusMessage "Please resolve security issues manually before committing" "Error" 0
                return
            }

            Write-StatusMessage "Security issues fixed successfully" "Success" 0
        }
        else {
            Write-StatusMessage "Cannot commit VS Code configuration with security issues" "Error" 0
            return
        }
    }

    # Collect VS Code files to commit
    $vsCodeFiles = @()
    $vsCodeFiles += Get-ChildItem -Path $vscodePath -Filter "*.json" | ForEach-Object { $_.FullName }

    if ($vsCodeFiles.Count -eq 0) {
        Write-StatusMessage "No VS Code configuration files found to commit" "Warning" 0
        return
    }

    Write-StatusMessage "Found $($vsCodeFiles.Count) VS Code configuration files to commit" "Success" 0

    # Commit the files
    $commitMessage = Read-Host "Enter commit message (or press Enter for default)"
    if ([string]::IsNullOrWhiteSpace($commitMessage)) {
        $commitMessage = "Update VS Code configuration settings"
    }

    $commitResult = New-SafeCommit -Files $vsCodeFiles -Message $commitMessage

    if ($commitResult) {
        Write-StatusMessage "VS Code configuration files committed successfully" "Success" 0
        Write-StatusMessage "Don't forget to push your changes with 'git push'" "Info" 0
    }
    else {
        Write-StatusMessage "Failed to commit VS Code configuration files" "Error" 0
    }

    Write-Host ""
}

# Run the commit process
Commit-VSCodeConfig
