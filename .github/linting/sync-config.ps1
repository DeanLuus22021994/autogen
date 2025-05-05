# Sync Markdown Linting Configuration
# This script syncs the markdown linting configuration files from .github/linting to the repository root

# Ensure we're in the repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Set-Location $repoRoot
}

# Define source and target files
$configFiles = @(
    @{
        Source = ".github\linting\.markdownlint-cli2.jsonc"
        Target = ".markdownlint-cli2.jsonc"
    },
    @{
        Source = ".github\linting\.markdownlint.json"
        Target = ".markdownlint.json"
    },
    @{
        Source = ".github\linting\.markdownlintignore"
        Target = ".markdownlintignore"
    },
    @{
        Source = ".github\linting\.markdownlintrc"
        Target = ".markdownlintrc"
    }
)

# Sync each file
foreach ($file in $configFiles) {
    if (Test-Path $file.Source) {
        Write-Host "Syncing $($file.Source) to $($file.Target)"
        Copy-Item -Path $file.Source -Destination $file.Target -Force
    } else {
        Write-Host "Warning: Source file $($file.Source) not found" -ForegroundColor Yellow
    }
}

Write-Host "Markdown linting configuration sync complete!" -ForegroundColor Green
Write-Host "Root configuration files are now linked to .github/linting"
