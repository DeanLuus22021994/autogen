# Clean up original files after migration to .toolbox is complete
# This script removes the original files that have been migrated to the .toolbox directory
# IMPORTANT: Only run this after verifying the .toolbox migration is complete and working correctly

param(
    [string[]]$MigratedFiles = @(
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
    ),
    [switch]$WhatIf = $false,
    [switch]$Force = $false,
    [switch]$Confirm
)

Write-Host "Cleaning up original files after .toolbox migration..." -ForegroundColor Cyan

Import-Module "$PSScriptRoot\modules\FileRemoval.psm1" -Force



if ($WhatIf) {
    Write-Host "Running in WhatIf mode. No files will be removed." -ForegroundColor Yellow
}

if ($Force) {
    Write-Host "Running in Force mode. No confirmation will be requested." -ForegroundColor Yellow
    $Confirm = $false
}


Write-Host "Files to be processed:" -ForegroundColor Cyan
foreach ($file in $MigratedFiles) {
    $status = if (Test-Path $file) { "Will be removed" } else { "Not found" }
    Write-Host "  $file - $status" -ForegroundColor Yellow
}


if (-not $Force) {
    $response = Read-Host "Do you want to proceed with cleanup? [Y/N]"
    if ($response -ne "Y" -and $response -ne "y") {
        Write-Host "Cleanup canceled." -ForegroundColor Yellow
        return
    }
}


# Process each file using the new module function
$params = @{}
if ($Force) { $params.Force = $true }
if ($WhatIf) { $params.WhatIf = $true }

$MigratedFiles | ForEach-Object {
    Remove-FileWithConfirmation -FilePath $_ @params
}

Write-Host "Cleanup completed." -ForegroundColor Green
