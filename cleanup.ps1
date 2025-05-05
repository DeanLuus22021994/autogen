$rootDir = "C:\Projects\autogen"

# More comprehensive list of problematic files based on the Git error
$problematicFiles = @(
    "22021994",
    "ecureToken = Read-Host Enter your GitHub Personal Access Token -AsSecureString",
    "t Found token in environment variables."
)

Write-Host "Searching for problematic files..." -ForegroundColor Cyan
# First attempt: Try to remove by exact name
foreach ($fileName in $problematicFiles) {
    $filePath = Join-Path -Path $rootDir -ChildPath $fileName
    if (Test-Path -LiteralPath $filePath) {
        Write-Host "Removing file: $fileName" -ForegroundColor Yellow
        Remove-Item -LiteralPath $filePath -Force
    } else {
        Write-Host "File not found by exact name: $fileName" -ForegroundColor Gray
    }
}

# Second attempt: Use Get-ChildItem more broadly to find problematic files
Write-Host "Searching for similarly named files..." -ForegroundColor Cyan
$patterns = @("*token*", "*GitHub*", "*Personal*", "*22021994*", "*Found*")
foreach ($pattern in $patterns) {
    Get-ChildItem -Path $rootDir -File -Include $pattern -Recurse:$false -Force | ForEach-Object {
        if ($_.DirectoryName -eq $rootDir) { # Only files in the root directory
            Write-Host "Found potentially problematic file: $($_.FullName)" -ForegroundColor Yellow
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }
}

# Now let's fix git config for line endings
Write-Host "Configuring Git line endings..." -ForegroundColor Cyan
git config --global core.autocrlf false
git config --global core.eol lf
Write-Host "Git configuration updated for line endings" -ForegroundColor Green

# Fix any other strange files in the root directory using wildcard
Write-Host "Cleaning up any remaining problematic files..." -ForegroundColor Cyan
Remove-Item -Path "$rootDir\t*" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$rootDir\*token*" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$rootDir\*Personal*" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$rootDir\*GitHub*" -Force -ErrorAction SilentlyContinue

# Check what's left
Write-Host "Remaining files in root directory:" -ForegroundColor Cyan
Get-ChildItem -Path $rootDir -File -Force | Where-Object { $_.DirectoryName -eq $rootDir } | ForEach-Object {
    Write-Host "- $($_.Name)" -ForegroundColor Gray
}

Write-Host "`nYou should now be able to run 'git add -A' successfully" -ForegroundColor Green
