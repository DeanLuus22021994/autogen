# Script to synchronize DIR.TAG files with identified problems in the codebase

param (
    [Parameter(Mandatory = $false)]
    [string]$RootPath = (git rev-parse --show-toplevel 2>$null),

    [Parameter(Mandatory = $false)]
    [string[]]$Directories,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Import required modules
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\modules\DirTagManagement.psm1'
if (-not (Test-Path $modulePath)) {
    throw "DirTagManagement.psm1 not found at $modulePath. Ensure the module exists in .toolbox/modules/."
}
Import-Module $modulePath -Force

$problemModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\modules\ProblemManagement.psm1'
if (-not (Test-Path $problemModulePath)) {
    throw "ProblemManagement.psm1 not found at $problemModulePath. Ensure the module exists in .toolbox/modules/."
}
Import-Module $problemModulePath -Force

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

Write-Host "Synchronizing DIR.TAG files with problems in $RootPath..." -ForegroundColor Cyan

# If no specific directories provided, identify key directories
if (-not $Directories -or $Directories.Count -eq 0) {
    $configDir = Join-Path -Path $RootPath -ChildPath ".config"
    $toolboxDir = Join-Path -Path $RootPath -ChildPath ".toolbox"
    $pythonDir = Join-Path -Path $RootPath -ChildPath "python"
    $dotnetDir = Join-Path -Path $RootPath -ChildPath "dotnet"

    $Directories = @(
        $configDir,
        $toolboxDir,
        $pythonDir,
        $dotnetDir,
        (Join-Path -Path $toolboxDir -ChildPath "config"),
        (Join-Path -Path $toolboxDir -ChildPath "modules"),
        (Join-Path -Path $pythonDir -ChildPath "autogen")
    )
}

$dirCount = $Directories.Count
$currentDir = 0

foreach ($dir in $Directories) {
    $currentDir++
    if (-not (Test-Path -Path $dir -PathType Container)) {
        Write-Host "Directory not found: $dir. Skipping..." -ForegroundColor Yellow
        continue
    }

    Write-Host "[$currentDir/$dirCount] Processing $dir..." -ForegroundColor Cyan

    # Get problems in the directory
    $problems = Get-DirectoryProblems -DirectoryPath $dir
    $errorCount = ($problems | Where-Object { $_.Type -eq 'error' }).Count
    $warningCount = ($problems | Where-Object { $_.Type -eq 'warning' }).Count
    $infoCount = ($problems | Where-Object { $_.Type -eq 'info' }).Count

    Write-Host "  Found $($problems.Count) problems: $errorCount errors, $warningCount warnings, $infoCount infos" -ForegroundColor $(
        if ($errorCount -gt 0) { "Red" }
        elseif ($warningCount -gt 0) { "Yellow" }
        else { "Green" }
    )

    # Update DIR.TAG file based on problems
    if ($WhatIf) {
        Write-Host "  WhatIf: Would update DIR.TAG in $dir based on problems" -ForegroundColor Cyan
    }
    else {
        $result = Update-DirTagFromProblems -DirectoryPath $dir -Force:$Force

        if ($result) {
            Write-Host "  Updated DIR.TAG in $dir successfully" -ForegroundColor Green
        }
        else {
            Write-Host "  Failed to update DIR.TAG in $dir" -ForegroundColor Red
        }
    }

    # Process subdirectories with found problems
    $subdirs = Get-ChildItem -Path $dir -Directory |
        Where-Object { $_.FullName -ne $dir }

    foreach ($subdir in $subdirs) {
        $subdirProblems = $problems | Where-Object {
            $_.FilePath -like "$($subdir.FullName)*"
        }

        if ($subdirProblems.Count -gt 0) {
            $subErrorCount = ($subdirProblems | Where-Object { $_.Type -eq 'error' }).Count
            $subWarningCount = ($subdirProblems | Where-Object { $_.Type -eq 'warning' }).Count
            $subInfoCount = ($subdirProblems | Where-Object { $_.Type -eq 'info' }).Count

            Write-Host "  - Subdir $($subdir.Name): $($subdirProblems.Count) problems: $subErrorCount errors, $subWarningCount warnings, $subInfoCount infos" -ForegroundColor $(
                if ($subErrorCount -gt 0) { "Red" }
                elseif ($subWarningCount -gt 0) { "Yellow" }
                else { "Green" }
            )

            if ($WhatIf) {
                Write-Host "    WhatIf: Would update DIR.TAG in $($subdir.FullName) based on problems" -ForegroundColor Cyan
            }
            else {
                $result = Update-DirTagFromProblems -DirectoryPath $subdir.FullName -Force:$Force

                if ($result) {
                    Write-Host "    Updated DIR.TAG in $($subdir.Name) successfully" -ForegroundColor Green
                }
                else {
                    Write-Host "    Failed to update DIR.TAG in $($subdir.Name)" -ForegroundColor Red
                }
            }
        }
    }
}

Write-Host "DIR.TAG synchronization with problems complete." -ForegroundColor Green
