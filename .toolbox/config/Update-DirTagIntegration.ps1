# Script to update DIR.TAG integration with problem tracking

param (
    [Parameter(Mandatory = $false)]
    [string]$RootPath = (git rev-parse --show-toplevel 2>$null),

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$UpdateConfig,

    [Parameter(Mandatory = $false)]
    [switch]$GenerateReport,

    [Parameter(Mandatory = $false)]
    [string]$ReportFormat = "Table", # Table, JSON, CSV, HTML

    [Parameter(Mandatory = $false)]
    [string]$ReportPath
)

# Import required modules
$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath '..\modules'

$requiredModules = @(
    "DirTagManagement",
    "ProblemManagement",
    "DirTagProblemIntegration"
)

foreach ($module in $requiredModules) {
    $modulePath = Join-Path -Path $modulesPath -ChildPath "$module.psm1"
    if (-not (Test-Path $modulePath)) {
        throw "$module.psm1 not found at $modulePath. Ensure the module exists in .toolbox/modules/."
    }
    # Use -Global flag to ensure functions are available across the script
    Import-Module $modulePath -Force -Global -Verbose
    Write-Host "Imported module: $module" -ForegroundColor Green
}

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

Write-Host "Working with repository: $RootPath" -ForegroundColor Cyan

# Update configuration if requested
if ($UpdateConfig) {
    $configDir = Join-Path -Path $RootPath -ChildPath ".config\dir-tag"
    if (-not (Test-Path -Path $configDir -PathType Container)) {
        try {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            Write-Host "Created config directory: $configDir" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to create config directory: $configDir. Error: $($_.Exception.Message)"
            exit 1
        }
    }

    # Run configuration update logic
    $syncPath = Join-Path -Path $PSScriptRoot -ChildPath 'Sync-DirTagConfig.ps1'
    if (Test-Path $syncPath) {
        try {
            & $syncPath -UpdateAll -Force:$Force
            Write-Host "DIR.TAG configuration updated successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "Error updating DIR.TAG configuration: $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Write-Error "Sync-DirTagConfig.ps1 not found at $syncPath"
        exit 1
    }
}

# Update DIR.TAG files with problem status
Write-Host "Updating DIR.TAG files with problem integration..." -ForegroundColor Cyan

# Get all directories with DIR.TAG files
$dirTagFiles = Get-ChildItem -Path $RootPath -Filter "DIR.TAG" -Recurse -File
$dirTagDirs = $dirTagFiles | ForEach-Object { Split-Path -Path $_.FullName -Parent }

$totalCount = $dirTagDirs.Count
$successCount = 0
$errorCount = 0

foreach ($dir in $dirTagDirs) {
    Write-Host "Processing $dir..." -ForegroundColor Yellow

    try {
        $result = Update-DirTagStatusFromProblems -DirectoryPath $dir -Force:$Force
        if ($result) {
            $successCount++
        }
        else {
            $errorCount++
            Write-Warning "Failed to update problem status for $dir"
        }
    }
    catch {
        $errorCount++
        Write-Error "Error updating $dir`: $($_.Exception.Message)"
    }
}

Write-Host "DIR.TAG problem integration completed." -ForegroundColor Green
Write-Host "Updated $successCount directories successfully, $errorCount failures out of $totalCount total." -ForegroundColor Cyan

# Generate report if requested
if ($GenerateReport) {
    Write-Host "Generating DIR.TAG problem integration report..." -ForegroundColor Cyan

    $summary = Get-DirTagProblemSummary -RootPath $RootPath -OutputFormat $ReportFormat

    if ($ReportPath) {
        $reportDir = Split-Path -Path $ReportPath -Parent
        if (-not (Test-Path -Path $reportDir -PathType Container)) {
            New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
        }

        switch ($ReportFormat) {
            "JSON" {
                $summary | Out-File -FilePath $ReportPath
            }
            "CSV" {
                $summary | Out-File -FilePath $ReportPath
            }
            "HTML" {
                # Convert to HTML
                $htmlReport = $summary | ConvertTo-Html -Title "DIR.TAG Problem Integration Report" -Property Path,Status,ErrorCount,WarningCount,InfoCount,TotalProblems,LastUpdated
                $htmlReport | Out-File -FilePath $ReportPath
            }
            default {
                $summary | Out-File -FilePath $ReportPath
            }
        }

        Write-Host "Report saved to $ReportPath" -ForegroundColor Green
    }
    else {
        # Display report directly
        $summary
    }
}

# Final status
if ($errorCount -eq 0) {
    Write-Host "DIR.TAG problem integration completed successfully!" -ForegroundColor Green
}
else {
    Write-Warning "DIR.TAG problem integration completed with $errorCount errors."
}
