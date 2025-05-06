# Clean up original files after migration to .toolbox is complete
# This script removes the original files that have been migrated to the .toolbox directory
# IMPORTANT: Only run this after verifying the .toolbox migration is complete and working correctly

param(
    [switch]$WhatIf = $false,
    [switch]$Force = $false,
    [switch]$Confirm = $true
)

Write-Host "Cleaning up original files after .toolbox migration..." -ForegroundColor Cyan

# List of files that have been migrated
$migratedFiles = @(
    "fix-docker-model-integration.ps1",
    "update-docker-extension-model-runner.ps1",
    "update-docker-extension.ps1",
    "fix-github-workflows.ps1",
    "setup-github-ssh.ps1",
    "Setup-GitSecureEnvironment.ps1",
    "Resolve-PushBlockedByToken.ps1",
    "add-markdown-rules-function.ps1",
    "Setup-AutogenEnvironment.ps1",
    "Reset-VSCodeEnvironment.ps1",
    "Validate-EnvSecrets.ps1",
    "Verify-GitHubSecrets.ps1",
    "Commit-SafeVsCodeConfig.ps1"
)

function Remove-FileWithConfirmation {
    param(
        [string]$FilePath,
        [bool]$ShouldConfirm,
        [bool]$IsWhatIf,
        [bool]$IsForce
    )

    if (Test-Path $FilePath) {
        $shouldRemove = $true

        if ($ShouldConfirm -and -not $IsForce) {
            $shouldRemove = $false
            $response = Read-Host "Remove file '$FilePath'? [Y/N]"
            if ($response -eq "Y" -or $response -eq "y") {
                $shouldRemove = $true
            }
        }

        if ($shouldRemove) {
            if ($IsWhatIf) {
                Write-Host "What if: Would remove file '$FilePath'" -ForegroundColor Yellow
            } else {
                try {
                    Remove-Item $FilePath -Force
                    Write-Host "Removed: $FilePath" -ForegroundColor Green
                } catch {
                    Write-Host "Error removing $FilePath: $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "Skipped: $FilePath" -ForegroundColor Gray
        }
    } else {
        Write-Host "Not found: $FilePath" -ForegroundColor Gray
    }
}

if ($WhatIf) {
    Write-Host "Running in WhatIf mode. No files will be removed." -ForegroundColor Yellow
}

if ($Force) {
    Write-Host "Running in Force mode. No confirmation will be requested." -ForegroundColor Yellow
    $Confirm = $false
}

# Print summary of files to be processed
Write-Host "Files to be processed:" -ForegroundColor Cyan
foreach ($file in $migratedFiles) {
    $status = "Not found"
    if (Test-Path $file) {
        $status = "Will be removed"
    }
    Write-Host "  $file - $status" -ForegroundColor Yellow
}

# Confirm before proceeding
if (-not $Force) {
    $response = Read-Host "Do you want to proceed with cleanup? [Y/N]"
    if ($response -ne "Y" -and $response -ne "y") {
        Write-Host "Cleanup canceled." -ForegroundColor Yellow
        return
    }
}

# Process each file
foreach ($file in $migratedFiles) {
    Remove-FileWithConfirmation -FilePath $file -ShouldConfirm $Confirm -IsWhatIf $WhatIf -IsForce $Force
}

Write-Host "Cleanup completed." -ForegroundColor Green
