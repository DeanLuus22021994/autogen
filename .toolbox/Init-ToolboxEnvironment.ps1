# Script to initialize the toolbox environment and ensure everything is properly setup

param (
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Banner
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  AutoGen Toolbox Environment Initializer  " -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

# Create default directory structure if it doesn't exist
$toolboxRoot = Split-Path -Path $PSScriptRoot -Parent
$toolboxDir = $PSScriptRoot

$requiredDirs = @(
    (Join-Path -Path $toolboxDir -ChildPath "modules"),
    (Join-Path -Path $toolboxDir -ChildPath "config"),
    (Join-Path -Path $toolboxDir -ChildPath "docker"),
    (Join-Path -Path $toolboxDir -ChildPath "github"),
    (Join-Path -Path $toolboxDir -ChildPath "markdown"),
    (Join-Path -Path $toolboxDir -ChildPath "security"),
    (Join-Path -Path $toolboxDir -ChildPath "environment"),
    (Join-Path -Path $toolboxDir -ChildPath "testing"),
    (Join-Path -Path $toolboxDir -ChildPath "workspace")
)

$configDirs = @(
    (Join-Path -Path $toolboxRoot -ChildPath ".config"),
    (Join-Path -Path $toolboxRoot -ChildPath ".config\dir-tag"),
    (Join-Path -Path $toolboxRoot -ChildPath ".config\host")
)

Write-Host "Setting up toolbox directory structure..." -ForegroundColor Cyan
foreach ($dir in $requiredDirs + $configDirs) {
    if (-not (Test-Path -Path $dir -PathType Container)) {
        try {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Host "  Created directory: $dir" -ForegroundColor Green
        }
        catch {
            Write-Host "  Failed to create directory $dir`: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  Directory already exists: $dir" -ForegroundColor Gray
    }
}

# Import DirTagManagement module
$modulePath = Join-Path -Path $toolboxDir -ChildPath "modules\DirTagManagement.psm1"
if (Test-Path $modulePath) {
    Write-Host "Importing DirTagManagement module..." -ForegroundColor Cyan
    Import-Module $modulePath -Force
}
else {
    Write-Host "DirTagManagement module not found at $modulePath" -ForegroundColor Red
}

# Create/update DIR.TAG files for toolbox directories
Write-Host "Creating/updating DIR.TAG files for toolbox directories..." -ForegroundColor Cyan

$syncPath = Join-Path -Path $toolboxDir -ChildPath "config\Sync-DirTagConfig.ps1"
if (Test-Path $syncPath) {
    try {
        & $syncPath -UpdateAll -Force:$Force
    }
    catch {
        Write-Host "Error running Sync-DirTagConfig.ps1: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "Sync-DirTagConfig.ps1 not found at $syncPath" -ForegroundColor Red
}

# Check for VS Code tasks
$vscodeDir = Join-Path -Path $toolboxRoot -ChildPath ".vscode"
$tasksPath = Join-Path -Path $vscodeDir -ChildPath "tasks.json"

Write-Host "Checking VS Code tasks configuration..." -ForegroundColor Cyan
if (-not (Test-Path -Path $vscodeDir -PathType Container)) {
    try {
        New-Item -Path $vscodeDir -ItemType Directory -Force | Out-Null
        Write-Host "  Created directory: $vscodeDir" -ForegroundColor Green
    }
    catch {
        Write-Host "  Failed to create directory $vscodeDir`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if (-not (Test-Path -Path $tasksPath) -or $Force) {
    try {
        # Create basic tasks.json if it doesn't exist
        $tasksJson = @{
            version = "2.0.0"
            tasks = @(
                @{
                    label = "Toolbox: Update DIR.TAG Files"
                    type = "shell"
                    command = "pwsh"
                    args = @(
                        "-File",
                        "`${workspaceFolder}\.toolbox\config\Sync-DirTagConfig.ps1",
                        "-UpdateAll"
                    )
                    group = @{
                        kind = "build"
                        isDefault = $false
                    }
                },
                @{
                    label = "Toolbox: Sync DIR.TAG with Problems"
                    type = "shell"
                    command = "pwsh"
                    args = @(
                        "-File",
                        "`${workspaceFolder}\.toolbox\config\Sync-DirTagProblems.ps1"
                    )
                    group = @{
                        kind = "test"
                        isDefault = $false
                    }
                },
                @{
                    label = "Toolbox: Generate DIR.TAG Report"
                    type = "shell"
                    command = "pwsh"
                    args = @(
                        "-File",
                        "`${workspaceFolder}\.toolbox\config\Generate-DirTagReport.ps1"
                    )
                    group = "test"
                },
                @{
                    label = "Toolbox: Run All Tests"
                    type = "shell"
                    command = "pwsh"
                    args = @(
                        "-Command",
                        "Invoke-Pester -Path `${workspaceFolder}\.toolbox\modules\*.Tests.ps1 -Output Detailed"
                    )
                    group = "test"
                },
                @{
                    label = "Toolbox: Open Workspace"
                    type = "shell"
                    command = "code"
                    args = @(
                        "`${workspaceFolder}\.toolbox\workspace\toolbox.code-workspace"
                    )
                    group = "none"
                }
            )
        }

        $existingTasksJson = $null
        if (Test-Path -Path $tasksPath) {
            $existingTasksJson = Get-Content -Path $tasksPath -Raw | ConvertFrom-Json

            # Merge existing tasks with toolbox tasks
            if ($existingTasksJson.tasks) {
                # Filter out any existing toolbox tasks
                $nonToolboxTasks = $existingTasksJson.tasks | Where-Object {
                    $_.label -notlike "Toolbox:*"
                }

                # Add the toolbox tasks
                $mergedTasks = $nonToolboxTasks + $tasksJson.tasks
                $existingTasksJson.tasks = $mergedTasks

                # Convert back to JSON
                $tasksJson = $existingTasksJson
            }
        }

        $tasksJson | ConvertTo-Json -Depth 5 | Set-Content -Path $tasksPath
        Write-Host "  Created/updated VS Code tasks.json" -ForegroundColor Green
    }
    catch {
        Write-Host "  Failed to create/update VS Code tasks.json: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "  VS Code tasks.json already exists (use -Force to update)" -ForegroundColor Gray
}

Write-Host "Toolbox environment initialization complete." -ForegroundColor Green
Write-Host "To open the toolbox workspace, run the 'Toolbox: Open Workspace' task in VS Code." -ForegroundColor Cyan
