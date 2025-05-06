# Script to clean up files that have been migrated to new locations
# This handles file cleanup for project reorganization

param (
    [Parameter(Mandatory = $false)]
    [string]$RootPath = (git rev-parse --show-toplevel 2>$null),

    [Parameter(Mandatory = $false)]
    [switch]$Force = $false,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludedPaths = @(".git", "node_modules", "bin", "obj", ".vs")
)

# Import the FileRemoval module
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'modules\FileRemoval.psm1'
if (-not (Test-Path $modulePath)) {
    throw "FileRemoval.psm1 not found at $modulePath. Ensure the module exists in .toolbox/modules/."
}
Import-Module $modulePath -Force

# Determine repository root if not provided
if (-not $RootPath) {
    $RootPath = Split-Path -Path $PSScriptRoot -Parent
    while (-not (Test-Path -Path (Join-Path -Path $RootPath -ChildPath ".git")) -and $RootPath -ne "") {
        $RootPath = Split-Path -Path $RootPath -Parent
    }

    if ($RootPath -eq "") {
        $RootPath = Get-Location
    }
}

Write-Host "Looking for migrated files in $RootPath..." -ForegroundColor Cyan

# Find migration markers in the repository
$migrationPatterns = @(
    "# Migrated to: ",
    "// Migrated to: ",
    "<!-- Migrated to: -->",
    "/* Migrated to: */"
)

$migratedFiles = @()

foreach ($pattern in $migrationPatterns) {
    # Skip excluded paths
    $excludeFilter = ($ExcludedPaths | ForEach-Object { "-not -path `"*/$_/*`"" }) -join " "

    try {
        # Use grep to find migration markers
        $grepCommand = "cd $RootPath && git grep -l `"$pattern`" -- . $excludeFilter"
        $foundFiles = Invoke-Expression $grepCommand

        if ($foundFiles) {
            $migratedFiles += $foundFiles
        }
    }
    catch {
        Write-Warning "Error searching for pattern '$pattern': $($_.Exception.Message)"
    }
}

# Remove duplicates
$migratedFiles = $migratedFiles | Sort-Object -Unique

Write-Host "Found $($migratedFiles.Count) potentially migrated files." -ForegroundColor Yellow

# Process the migrated files
foreach ($file in $migratedFiles) {
    $fullPath = Join-Path -Path $RootPath -ChildPath $file

    # Extract the migration target
    $content = Get-Content -Path $fullPath -Raw
    $target = ""

    foreach ($pattern in $migrationPatterns) {
        if ($content -match "$pattern(.*?)(\r?\n|$)") {
            $target = $matches[1].Trim()
            break
        }
    }

    if ($target) {
        $targetPath = Join-Path -Path $RootPath -ChildPath $target

        # Check if the target exists
        if (Test-Path $targetPath) {
            Write-Host "File '$file' has been migrated to '$target' and target exists." -ForegroundColor Cyan

            # Remove the file if confirmed or forced
            if ($Force) {
                Remove-FileWithConfirmation -FilePath $fullPath -Force:$Force -WhatIf:$WhatIf
            }
            else {
                $confirmation = Read-Host "Do you want to remove '$file'? (Y/n)"
                if ($confirmation -eq "Y" -or $confirmation -eq "y" -or $confirmation -eq "") {
                    Remove-FileWithConfirmation -FilePath $fullPath -WhatIf:$WhatIf
                }
                else {
                    Write-Host "Skipped: $file" -ForegroundColor Yellow
                }
            }
        }
        else {
            Write-Warning "File '$file' claims to be migrated to '$target', but target does not exist."
        }
    }
    else {
        Write-Warning "Could not determine migration target for '$file'."
    }
}

if ($migratedFiles.Count -eq 0) {
    Write-Host "No migrated files found." -ForegroundColor Green
}
else {
    Write-Host "Cleanup operation complete." -ForegroundColor Green
}
