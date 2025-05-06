# Update file paths in moved scripts
# This script updates relative path references in scripts that have been moved to the .toolbox directory

Write-Host "Updating paths in moved scripts..." -ForegroundColor Cyan

$toolboxScripts = Get-ChildItem -Path ".toolbox" -Recurse -Filter "*.ps1"

foreach ($script in $toolboxScripts) {
    Write-Host "Processing $($script.Name)..." -ForegroundColor Yellow

    # Read the content of the script
    $content = Get-Content -Path $script.FullName -Raw

    # Update relative paths for files that are now in a subdirectory
    # Add "../.." to paths that reference the root directory
    $updatedContent = $content -replace '"\$PSScriptRoot\\', '"\$PSScriptRoot\..\..\\'
    $updatedContent = $updatedContent -replace '"\$PSScriptRoot/', '"\$PSScriptRoot/../../'

    # Special case for paths without $PSScriptRoot but direct references
    $updatedContent = $updatedContent -replace '="\./', '="../../'
    $updatedContent = $updatedContent -replace '="\.\\', '="..\..\\'

    # Write the updated content back to the file
    if ($content -ne $updatedContent) {
        Set-Content -Path $script.FullName -Value $updatedContent
        Write-Host "  Updated paths in $($script.Name)" -ForegroundColor Green
    } else {
        Write-Host "  No path updates needed in $($script.Name)" -ForegroundColor Gray
    }
}

Write-Host "Path updates completed" -ForegroundColor Green
