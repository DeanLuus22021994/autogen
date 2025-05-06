# Synchronize DIR.TAG files between bash and PowerShell implementations
# This script ensures compatibility between the PowerShell and bash DIR.TAG management systems

param (
    [Parameter(Mandatory = $false)]
    [string]$RootPath = (git rev-parse --show-toplevel 2>$null),

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$UpdateAll
)

# Import the DirTagManagement module
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\modules\DirTagManagement.psm1'
if (-not (Test-Path $modulePath)) {
    throw "DirTagManagement.psm1 not found at $modulePath. Ensure the module exists in .toolbox/modules/."
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

Write-Host "Synchronizing DIR.TAG files in $RootPath..." -ForegroundColor Cyan

# Find all DIR.TAG files
$dirTags = Find-DirTags -RootPath $RootPath -IncludeContent -ValidateAll

Write-Host "Found $($dirTags.Count) DIR.TAG files." -ForegroundColor Green

# Group by validity
$validDirTags = $dirTags | Where-Object { $_.Valid }
$invalidDirTags = $dirTags | Where-Object { -not $_.Valid }

Write-Host "$($validDirTags.Count) valid, $($invalidDirTags.Count) invalid DIR.TAG files." -ForegroundColor $(if ($invalidDirTags.Count -gt 0) { "Yellow" } else { "Green" })

# Process invalid DIR.TAG files
if ($invalidDirTags.Count -gt 0) {
    Write-Host "Invalid DIR.TAG files:" -ForegroundColor Yellow

    foreach ($invalidTag in $invalidDirTags) {
        Write-Host "  - $($invalidTag.Path)" -ForegroundColor Yellow
        foreach ($issue in $invalidTag.Issues) {
            Write-Host "    * $issue" -ForegroundColor Yellow
        }

        # Update invalid DIR.TAG files if requested
        if ($UpdateAll -or $Force) {
            Write-Host "    Updating invalid DIR.TAG..." -ForegroundColor Cyan

            # Extract existing data if possible
            $description = ""
            $status = "NOT_STARTED"
            $todoItems = @()

            if ($invalidTag.Content) {
                # Try to extract description
                if ($invalidTag.Content -match 'description:\s*\|\s*\n((?:.+\n)+)') {
                    $description = $matches[1].Trim()
                }

                # Try to extract status
                if ($invalidTag.Content -match 'status:\s*([^\n]+)') {
                    $status = $matches[1].Trim()
                }

                # Try to extract TODO items
                if ($invalidTag.Content -match '#TODO:\s*\n((?:\s*-\s*.+\n)+)') {
                    $todoItemMatches = $matches[1] -split "`n" | Where-Object { $_ -match '\s*-\s*(.+)' }
                    $todoItems = $todoItemMatches | ForEach-Object {
                        if ($_ -match '\s*-\s*(.+)') {
                            $matches[1].Trim()
                        }
                    }
                }
            }

            if ($WhatIf) {
                Write-Host "    WhatIf: Would update DIR.TAG at $($invalidTag.Path)" -ForegroundColor Cyan
            } else {
                $updateParams = @{
                    DirectoryPath = $invalidTag.Path
                    Force = $true
                }

                if ($description) { $updateParams.Description = $description }
                if ($status) { $updateParams.Status = $status }
                if ($todoItems.Count -gt 0) { $updateParams.TodoItems = $todoItems }

                $result = New-DirTag @updateParams

                if ($result) {
                    Write-Host "    Updated DIR.TAG successfully." -ForegroundColor Green
                } else {
                    Write-Host "    Failed to update DIR.TAG." -ForegroundColor Red
                }
            }
        }
    }
}

# Check for missing DIR.TAG files in key directories
$configDir = Join-Path -Path $RootPath -ChildPath ".config"
$toolboxDir = Join-Path -Path $RootPath -ChildPath ".toolbox"

$keyDirectories = @(
    $configDir,
    $toolboxDir,
    (Join-Path -Path $toolboxDir -ChildPath "config"),
    (Join-Path -Path $toolboxDir -ChildPath "modules"),
    (Join-Path -Path $toolboxDir -ChildPath "docker"),
    (Join-Path -Path $toolboxDir -ChildPath "github"),
    (Join-Path -Path $toolboxDir -ChildPath "markdown"),
    (Join-Path -Path $toolboxDir -ChildPath "security"),
    (Join-Path -Path $toolboxDir -ChildPath "environment"),
    (Join-Path -Path $toolboxDir -ChildPath "testing")
)

Write-Host "Checking for missing DIR.TAG files in key directories..." -ForegroundColor Cyan

foreach ($dir in $keyDirectories) {
    if (Test-Path -Path $dir -PathType Container) {
        $dirTagPath = Join-Path -Path $dir -ChildPath "DIR.TAG"

        if (-not (Test-Path -Path $dirTagPath)) {
            Write-Host "  Missing DIR.TAG in $dir" -ForegroundColor Yellow

            if ($UpdateAll -or $Force) {
                $description = "Configuration directory for $($dir.Replace($RootPath, '').TrimStart('\').Replace('\', '/'))"

                if ($WhatIf) {
                    Write-Host "  WhatIf: Would create DIR.TAG in $dir" -ForegroundColor Cyan
                } else {
                    $result = New-DirTag -DirectoryPath $dir -Description $description

                    if ($result) {
                        Write-Host "  Created DIR.TAG in $dir" -ForegroundColor Green
                    } else {
                        Write-Host "  Failed to create DIR.TAG in $dir" -ForegroundColor Red
                    }
                }
            }
        }
    }
}

# Add GUID to DIR.TAG files that don't have one
$noGuidTags = $dirTags | Where-Object { $_.Content -notmatch '#GUID:' }

if ($noGuidTags.Count -gt 0) {
    Write-Host "Found $($noGuidTags.Count) DIR.TAG files without GUID." -ForegroundColor Yellow

    if ($UpdateAll -or $Force) {
        foreach ($tag in $noGuidTags) {
            Write-Host "  Adding GUID to $($tag.Path)" -ForegroundColor Cyan

            # Extract existing data
            $description = ""
            $status = "NOT_STARTED"
            $todoItems = @()

            if ($tag.Content) {
                # Try to extract description
                if ($tag.Content -match 'description:\s*\|\s*\n((?:.+\n)+)') {
                    $description = $matches[1].Trim()
                }

                # Try to extract status
                if ($tag.Content -match 'status:\s*([^\n]+)') {
                    $status = $matches[1].Trim()
                }

                # Try to extract TODO items
                if ($tag.Content -match '#TODO:\s*\n((?:\s*-\s*.+\n)+)') {
                    $todoItemMatches = $matches[1] -split "`n" | Where-Object { $_ -match '\s*-\s*(.+)' }
                    $todoItems = $todoItemMatches | ForEach-Object {
                        if ($_ -match '\s*-\s*(.+)') {
                            $matches[1].Trim()
                        }
                    }
                }
            }

            if ($WhatIf) {
                Write-Host "    WhatIf: Would update DIR.TAG with GUID at $($tag.Path)" -ForegroundColor Cyan
            } else {
                $updateParams = @{
                    DirectoryPath = $tag.Path
                    Force = $true
                }

                if ($description) { $updateParams.Description = $description }
                if ($status) { $updateParams.Status = $status }
                if ($todoItems.Count -gt 0) { $updateParams.TodoItems = $todoItems }

                $result = New-DirTag @updateParams

                if ($result) {
                    Write-Host "    Added GUID to DIR.TAG successfully." -ForegroundColor Green
                } else {
                    Write-Host "    Failed to add GUID to DIR.TAG." -ForegroundColor Red
                }
            }
        }
    }
}

Write-Host "DIR.TAG synchronization complete." -ForegroundColor Green
