# PowerShell script to sync smoll2-related DIR.TAG files
# This script uses the DirTagGroupManagement module to manage smoll2/RAM disk related DIR.TAG files

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$UpdateStatus,

    [Parameter(Mandatory = $false)]
    [ValidateSet("OUTSTANDING", "PARTIALLY_COMPLETE", "DONE")]
    [string]$NewStatus = "PARTIALLY_COMPLETE"
)

# Import required modules
$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\modules"
$dirTagGroupManagementPath = Join-Path -Path $modulesPath -ChildPath "DirTagGroupManagement.psm1"

if (-not (Test-Path -Path $dirTagGroupManagementPath)) {
    Write-Error "DirTagGroupManagement module not found at: $dirTagGroupManagementPath"
    exit 1
}

Import-Module $dirTagGroupManagementPath -Force

# Define a function to create a group for smoll2/RAM disk related directories
function Get-Smoll2RamDiskDirTagGroup {
    [CmdletBinding()]
    param()

    # Get the repository root directory
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $repoRoot) {
        $repoRoot = "c:\Projects\autogen"
    }

    # Create a group for smoll2/RAM disk related DIR.TAG files
    $group = New-DirTagGroup -Name "Smoll2RamDisk" -Description "DIR.TAG files related to smoll2 LLM with RAM disk optimization"

    # Add common smoll2/RAM disk related directories
    $group.AddDirectory("$repoRoot\.devcontainer")
    $group.AddDirectory("$repoRoot\.devcontainer\docker")
    $group.AddDirectory("$repoRoot\.devcontainer\swarm")
    $group.AddDirectory("$repoRoot\.toolbox\docker")
    $group.AddDirectory("$repoRoot\.toolbox\modules")
    $group.AddDirectory("$repoRoot\docs")

    # Add pattern for any smoll2/RAM disk related directories
    $group.AddDirectoryPattern("$repoRoot\**\*ramdisk*")
    $group.AddDirectoryPattern("$repoRoot\**\*smoll2*")

    # Metadata for smoll2/RAM disk group
    $group.Metadata = @{
        Category = "Performance"
        Priority = "High"
        RelatedTech = @("RAM Disk", "Docker", "Swarm", "GPU", "LLM", "smoll2")
    }

    return $group
}

# Define smoll2/RAM disk related TODO items
$smoll2RamDiskTodoItems = @(
    "Configure RAM disk for smoll2 model weights [OUTSTANDING]",
    "Set up efficient memory management for LLM inference [OUTSTANDING]",
    "Implement smoll2 model with Docker Model Runner [OUTSTANDING]",
    "Configure Docker Swarm for smoll2 high-performance inference [OUTSTANDING]",
    "Create performance benchmarking for smoll2 with/without RAM disk [OUTSTANDING]",
    "Optimize GPU memory allocation for smoll2 model [OUTSTANDING]",
    "Document RAM disk setup process for smoll2 deployment [OUTSTANDING]",
    "Implement monitoring for RAM disk usage and performance [OUTSTANDING]"
)

# Update TODO items based on current status if requested
if ($UpdateStatus) {
    $smoll2RamDiskTodoItems = $smoll2RamDiskTodoItems | ForEach-Object {
        if ($_ -match '(.+)\s*\[.+\]') {
            "$($matches[1]) [$NewStatus]"
        } else {
            "$_ [$NewStatus]"
        }
    }
}

# Get the smoll2/RAM disk group
$smoll2Group = Get-Smoll2RamDiskDirTagGroup

# Add smoll2/RAM disk TODO items to the group
foreach ($item in $smoll2RamDiskTodoItems) {
    Write-Verbose "Adding TODO item: $item"

    $params = @{
        Group = $smoll2Group
        Operation = [DirTagGroupOperation]::Add
        TodoItem = $item
        Force = $Force
        WhatIf = $WhatIf
    }

    $result = Invoke-DirTagGroupOperation @params

    if ($result) {
        foreach ($dirResult in $result) {
            if ($dirResult.Success) {
                Write-Host "✅ $($dirResult.Message)" -ForegroundColor Green
            } else {
                Write-Host "❌ $($dirResult.Message)" -ForegroundColor Red
            }
        }
    }
}

# If UpdateStatus is specified, update the status of all smoll2/RAM disk TODO items
if ($UpdateStatus) {
    Write-Host "Updating status of smoll2/RAM disk TODO items to $NewStatus..." -ForegroundColor Cyan

    foreach ($item in $smoll2RamDiskTodoItems) {
        $taskDesc = $item -replace '\s*\[.+\]', ''

        $params = @{
            Group = $smoll2Group
            Operation = [DirTagGroupOperation]::Update
            TodoItem = $taskDesc
            Status = $NewStatus
            Force = $Force
            WhatIf = $WhatIf
        }

        $result = Invoke-DirTagGroupOperation @params

        if ($result) {
            foreach ($dirResult in $result) {
                if ($dirResult.Success) {
                    Write-Host "✅ $($dirResult.Message)" -ForegroundColor Green
                } else {
                    Write-Host "❌ $($dirResult.Message)" -ForegroundColor Red
                }
            }
        }
    }
}

# If WhatIf is specified, show what would happen
if ($WhatIf) {
    Write-Host "WhatIf: Would update DIR.TAG files in the following directories:" -ForegroundColor Yellow
    $smoll2Group.ResolveDirectories() | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White
    }
} else {
    Write-Host "Completed synchronizing smoll2/RAM disk related DIR.TAG files" -ForegroundColor Green

    # Provide suggestions for next steps
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Review DIR.TAG files in related directories" -ForegroundColor White
    Write-Host "2. Update status as implementation progresses using:" -ForegroundColor White
    Write-Host "   .\Sync-Smoll2DirTags.ps1 -UpdateStatus -NewStatus DONE" -ForegroundColor Yellow
    Write-Host "3. Validate DIR.TAG consistency across the project:" -ForegroundColor White
    Write-Host "   Invoke-Pester -Path ..\modules\DirTagGroupManagement.Tests.ps1" -ForegroundColor Yellow
}
