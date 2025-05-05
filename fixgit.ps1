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

# Second attempt: Find files with problematic content or names
Write-Host "Searching for similarly named files in root directory only..." -ForegroundColor Cyan
$rootFiles = Get-ChildItem -Path $rootDir -File -Force | Where-Object { $_.DirectoryName -eq $rootDir }
foreach ($file in $rootFiles) {
    $isProblematicFile = $false

    # Check if the file name contains any of these keywords
    $keywords = @("token", "GitHub", "Personal", "22021994", "Found")
    foreach ($keyword in $keywords) {
        if ($file.Name -like "*$keyword*") {
            $isProblematicFile = $true
            break
        }
    }

    # Check if it's a peculiar file (not in our list of expected files)
    $expectedFiles = @(
        ".gitattributes", ".gitignore", "AutoGen-DevContainerEnhancement.code-workspace",
        "autogen-landing.jpg", "cleanup.ps1", "fixgit.ps1", "CODE_OF_CONDUCT.md", "codecov.yml",
        "CONTRIBUTING.md", "FAQ.md", "LICENSE", "LICENSE-CODE", "menu.py",
        "README.md", "SECURITY.md", "SUPPORT.md"
    )

    if (-not ($expectedFiles -contains $file.Name)) {
        Write-Host "Found unexpected file: $($file.Name)" -ForegroundColor Yellow
        $isProblematicFile = $true
    }

    if ($isProblematicFile) {
        Write-Host "Found potentially problematic file: $($file.FullName)" -ForegroundColor Yellow
        Remove-Item -LiteralPath $file.FullName -Force
    }
}

# Now let's fix git config for line endings
Write-Host "Configuring Git line endings..." -ForegroundColor Cyan
git config --global core.autocrlf false
git config --global core.eol lf
git config --global core.safecrlf false  # Don't warn about CRLF conversions
Write-Host "Git configuration updated for line endings" -ForegroundColor Green

# Create/update .gitattributes file to enforce LF
$gitattributesPath = Join-Path -Path $rootDir -ChildPath ".gitattributes"
$gitattributesContent = @"
# Set default behavior to LF
* text=auto eol=lf

# Binary files
*.jpg binary
*.png binary
*.gif binary
"@
Set-Content -Path $gitattributesPath -Value $gitattributesContent
Write-Host "Updated .gitattributes file to enforce LF line endings" -ForegroundColor Green

# Check what's left
Write-Host "Remaining files in root directory:" -ForegroundColor Cyan
Get-ChildItem -Path $rootDir -File -Force | Where-Object { $_.DirectoryName -eq $rootDir } | ForEach-Object {
    Write-Host "- $($_.Name)" -ForegroundColor Gray
}

# Try git add command
Write-Host "`nAttempting to run 'git add -A' now..." -ForegroundColor Cyan
$currentLocation = Get-Location
Set-Location -Path $rootDir
try {
    $gitOutput = & git add -A 2>&1
    $gitExitCode = $LASTEXITCODE

    if ($gitExitCode -eq 0) {
        Write-Host "Git add successful!" -ForegroundColor Green
        Write-Host "`nYou can now run 'git commit' to commit your changes" -ForegroundColor Green
    } else {
        Write-Host "Git add still has issues:" -ForegroundColor Red
        $gitOutput | ForEach-Object { Write-Host $_ -ForegroundColor Red }

        # List all files with unusual attributes for debugging
        Write-Host "`nListing all files in root directory:" -ForegroundColor Cyan
        cmd /c dir /a /q "$rootDir"
    }
} finally {
    Set-Location -Path $currentLocation
}
