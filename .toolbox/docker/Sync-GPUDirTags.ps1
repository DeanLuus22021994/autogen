# PowerShell script to sync GPU-related DIR.TAG files
# This script uses the DirTagGroupManagement module to manage GPU-related DIR.TAG files

param (
    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# Set VerbosePreference based on the Verbose switch
if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Import required modules
$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\modules"
$dirTagGroupManagementPath = Join-Path -Path $modulesPath -ChildPath "DirTagGroupManagement.psm1"

if (-not (Test-Path -Path $dirTagGroupManagementPath)) {
    Write-Error "DirTagGroupManagement module not found at: $dirTagGroupManagementPath"
    exit 1
}

Import-Module $dirTagGroupManagementPath -Force

# Sync GPU-related DIR.TAG files
Write-Host "Syncing GPU-related DIR.TAG files..." -ForegroundColor Cyan

try {
    $results = Sync-GPURelatedDirTags -Force:$Force -WhatIf:$WhatIf

    if ($WhatIf) {
        Write-Host "What-If: The following directories would be updated:" -ForegroundColor Yellow
        $results | ForEach-Object {
            Write-Host "  - $($_.Directory): $($_.Message)" -ForegroundColor Yellow
        }
    } else {
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count

        Write-Host "GPU-related DIR.TAG sync completed!" -ForegroundColor Green
        Write-Host "  - Successfully updated: $successCount" -ForegroundColor Green

        if ($failureCount -gt 0) {
            Write-Host "  - Failed to update: $failureCount" -ForegroundColor Red
            Write-Host "Failures:" -ForegroundColor Red
            $results | Where-Object { -not $_.Success } | ForEach-Object {
                Write-Host "  - $($_.Directory): $($_.Message)" -ForegroundColor Red
            }
        }
    }

    # Display verbose results
    if ($Verbose) {
        Write-Verbose "Detailed results:"
        $results | ForEach-Object {
            Write-Verbose "  - $($_.Directory): $($_.Message) (Success: $($_.Success))"
        }
    }
} catch {
    Write-Error "Error syncing GPU-related DIR.TAG files: $_"
    exit 1
}

# Verify GPU-related DIR.TAG files
Write-Host "Verifying GPU-related DIR.TAG files..." -ForegroundColor Cyan

try {
    $verificationResults = Test-GPUDirTags -Detailed

    $validCount = ($verificationResults | Where-Object { $_.Success }).Count
    $invalidCount = ($verificationResults | Where-Object { -not $_.Success }).Count

    Write-Host "GPU-related DIR.TAG verification completed!" -ForegroundColor Green
    Write-Host "  - Valid: $validCount" -ForegroundColor Green

    if ($invalidCount -gt 0) {
        Write-Host "  - Invalid: $invalidCount" -ForegroundColor Red
        Write-Host "Invalid files:" -ForegroundColor Red
        $verificationResults | Where-Object { -not $_.Success } | ForEach-Object {
            Write-Host "  - $($_.Directory): $($_.Message)" -ForegroundColor Red
        }
    }
} catch {
    Write-Error "Error verifying GPU-related DIR.TAG files: $_"
    exit 1
}

# Suggest common GPU tasks that might be missing
Write-Host "Checking for common GPU tasks that might be missing..." -ForegroundColor Cyan

$commonGpuTasks = @(
    "Configure NVIDIA GPU passthrough for Docker containers",
    "Implement GPU resource allocation for AI model inference",
    "Set up container health checks for GPU availability",
    "Optimize Docker Swarm settings for high-performance operation",
    "Configure memory settings for GPU-accelerated workloads",
    "Create performance benchmarks for GPU-enabled containers",
    "Implement auto-scaling based on GPU usage metrics"
)

$gpuGroup = Get-GPUConfigurationDirTagGroup
$directories = $gpuGroup.ResolveDirectories()

$taskCoverage = @{}
foreach ($task in $commonGpuTasks) {
    $taskCoverage[$task] = 0
}

foreach ($dir in $directories) {
    $dirTagPath = Join-Path -Path $dir -ChildPath "DIR.TAG"

    if (Test-Path $dirTagPath) {
        $content = Get-Content -Path $dirTagPath -Raw

        foreach ($task in $commonGpuTasks) {
            if ($content -match [regex]::Escape($task)) {
                $taskCoverage[$task]++
            }
        }
    }
}

$missingTasks = @()
foreach ($task in $commonGpuTasks) {
    $coverage = $taskCoverage[$task]
    $percentage = [math]::Round(($coverage / $directories.Count) * 100)

    if ($percentage -lt 50) {
        $missingTasks += $task
    }
}

if ($missingTasks.Count -gt 0) {
    Write-Host "The following common GPU tasks are missing from many directories:" -ForegroundColor Yellow
    foreach ($task in $missingTasks) {
        Write-Host "  - $task" -ForegroundColor Yellow
        Write-Host "    Would you like to add this task to all GPU-related directories? (y/n)"
        $response = Read-Host

        if ($response -eq "y") {
            $addResults = Add-GPUTaskToDirTags -TaskDescription $task -Status "OUTSTANDING" -Force:$Force
            Write-Host "    Added task to $($addResults.Count) directories." -ForegroundColor Green
        }
    }
} else {
    Write-Host "All common GPU tasks are well represented across directories." -ForegroundColor Green
}

Write-Host "GPU DIR.TAG synchronization completed!" -ForegroundColor Green
