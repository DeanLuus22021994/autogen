<#
.SYNOPSIS
    Generates a standardized DIR.TAG template for a directory.
.DESCRIPTION
    This script creates a standardized DIR.TAG file template based on the
    directory path and provided task information. It follows the established
    AutoGen project patterns for DIR.TAG files.
.PARAMETER DirectoryPath
    The path of the directory to create the DIR.TAG file for.
.PARAMETER Tasks
    Array of task descriptions to include in the TODO section.
.PARAMETER Status
    Overall status of the directory. Valid values: NOT_STARTED, PARTIALLY_COMPLETE, DONE, OUTSTANDING.
.PARAMETER Description
    Detailed description of the directory's purpose.
.EXAMPLE
    .\Generate-DirTagTemplate.ps1 -DirectoryPath ".toolbox/docker" -Tasks @("Task 1", "Task 2") -Status "PARTIALLY_COMPLETE" -Description "Docker integration tools."
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$DirectoryPath,

    [Parameter(Mandatory = $false)]
    [string[]]$Tasks = @("Initial directory structure setup"),

    [Parameter(Mandatory = $false)]
    [ValidateSet("NOT_STARTED", "PARTIALLY_COMPLETE", "DONE", "OUTSTANDING")]
    [string]$Status = "NOT_STARTED",

    [Parameter(Mandatory = $false)]
    [string]$Description = "Directory purpose description."
)

# Import required modules
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "modules\DirTagManagement.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}

function Format-Tasks {
    param (
        [string[]]$Tasks
    )

    $formattedTasks = ""
    foreach ($task in $Tasks) {
        if ($task -match "(.*)\s+(NOT_STARTED|PARTIALLY_COMPLETE|DONE|OUTSTANDING)$") {
            $formattedTasks += "  - $task`n"
        } else {
            $formattedTasks += "  - $task NOT_STARTED`n"
        }
    }

    return $formattedTasks
}

# Get current timestamp in ISO 8601 format
$timestamp = Get-Date -Format "o"

# Format tasks
$formattedTasks = Format-Tasks -Tasks $Tasks

# Create DIR.TAG content
$dirTagContent = @"
#INDEX: $DirectoryPath
#TODO:
$formattedTasks
status: $Status
updated: $timestamp
description: |
  $Description
"@

# Determine the output path
$dirName = Split-Path -Path $DirectoryPath -Leaf
$dirPath = if ($DirectoryPath.StartsWith(".")) {
    # Relative path
    Join-Path -Path $PSScriptRoot -ChildPath ".." | Join-Path -ChildPath $DirectoryPath
} else {
    # Absolute path
    $DirectoryPath
}

# Create directory if it doesn't exist
if (-not (Test-Path $dirPath)) {
    New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
}

# Output path for the DIR.TAG file
$outputPath = Join-Path -Path $dirPath -ChildPath "DIR.TAG"

# Write content to DIR.TAG file
Set-Content -Path $outputPath -Value $dirTagContent

Write-Host "DIR.TAG file has been generated at: $outputPath" -ForegroundColor Green

# If DirTagManagement module is available, register the DIR.TAG
if (Get-Command -Name "Update-DirTag" -ErrorAction SilentlyContinue) {
    try {
        Update-DirTag -Path $outputPath -Force
        Write-Host "DIR.TAG file has been registered with the management system." -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not register DIR.TAG with management system: $_"
    }
}