# Script to generate a report of DIR.TAG status across the project

param (
    [Parameter(Mandatory = $false)]
    [string]$RootPath = (git rev-parse --show-toplevel 2>$null),

    [Parameter(Mandatory = $false)]
    [string]$OutputFormat = "Console", # Console, CSV, JSON, HTML

    [Parameter(Mandatory = $false)]
    [string]$OutputFile,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeDetails
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

Write-Host "Generating DIR.TAG report for $RootPath..." -ForegroundColor Cyan

# Find all DIR.TAG files
$dirTags = Find-DirTags -RootPath $RootPath -IncludeContent -ValidateAll

# Process the DIR.TAG files for reporting
$report = @()

foreach ($tag in $dirTags) {
    $dirTagData = [PSCustomObject]@{
        Path = $tag.RelativePath
        Status = "Unknown"
        TodoCount = 0
        CompletedTodos = 0
        HasGuid = $false
        IsValid = $tag.Valid
        Issues = $tag.Issues -join "; "
    }

    if ($tag.Content) {
        # Extract status
        if ($tag.Content -match 'status:\s*([^\n]+)') {
            $dirTagData.Status = $matches[1].Trim()
        }

        # Extract GUID
        if ($tag.Content -match '#GUID:\s*([a-fA-F0-9-]+)') {
            $dirTagData.HasGuid = $true
        }

        # Extract TODO items
        if ($tag.Content -match '#TODO:\s*\n((?:\s*-\s*.+\n)+)') {
            $todoItems = $matches[1] -split "`n" |
                Where-Object { $_ -match '\s*-\s*(.+)' } |
                ForEach-Object { $matches[1].Trim() }

            $dirTagData.TodoCount = $todoItems.Count
            $dirTagData.CompletedTodos = ($todoItems | Where-Object { $_ -match '\[DONE\]$' }).Count
        }
    }

    $report += $dirTagData
}

# Generate summary
$summary = [PSCustomObject]@{
    TotalDirTags = $dirTags.Count
    ValidDirTags = ($dirTags | Where-Object { $_.Valid }).Count
    InvalidDirTags = ($dirTags | Where-Object { -not $_.Valid }).Count
    WithGuid = ($report | Where-Object { $_.HasGuid }).Count
    WithoutGuid = ($report | Where-Object { -not $_.HasGuid }).Count
    StatusSummary = $report | Group-Object -Property Status | ForEach-Object {
        [PSCustomObject]@{
            Status = $_.Name
            Count = $_.Count
            Percentage = [Math]::Round(($_.Count / $report.Count) * 100, 2)
        }
    }
    TodosTotal = ($report | Measure-Object -Property TodoCount -Sum).Sum
    TodosCompleted = ($report | Measure-Object -Property CompletedTodos -Sum).Sum
    CompletionPercentage = 0
}

if ($summary.TodosTotal -gt 0) {
    $summary.CompletionPercentage = [Math]::Round(($summary.TodosCompleted / $summary.TodosTotal) * 100, 2)
}

# Output the report based on the specified format
switch ($OutputFormat.ToLower()) {
    "csv" {
        if (-not $OutputFile) {
            $OutputFile = "DirTagReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        }
        $report | Export-Csv -Path $OutputFile -NoTypeInformation
        Write-Host "Report saved to $OutputFile" -ForegroundColor Green
    }
    "json" {
        if (-not $OutputFile) {
            $OutputFile = "DirTagReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        }
        $reportData = [PSCustomObject]@{
            Summary = $summary
            Details = $report
        }
        $reportData | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputFile
        Write-Host "Report saved to $OutputFile" -ForegroundColor Green
    }
    "html" {
        if (-not $OutputFile) {
            $OutputFile = "DirTagReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
        }

        # Build a simple HTML report
        $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>DIR.TAG Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { padding: 8px; border: 1px solid #ddd; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .summary { margin-bottom: 30px; }
        .status-NOT_STARTED { color: #888888; }
        .status-PARTIALLY_COMPLETE { color: #FFA500; }
        .status-DONE { color: #00AA00; }
        .status-OUTSTANDING { color: #FF0000; }
    </style>
</head>
<body>
    <h1>DIR.TAG Report</h1>

    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total DIR.TAG files:</strong> $($summary.TotalDirTags)</p>
        <p><strong>Valid DIR.TAG files:</strong> $($summary.ValidDirTags) ($(if($summary.TotalDirTags -gt 0){[Math]::Round(($summary.ValidDirTags / $summary.TotalDirTags) * 100, 2)}else{0})%)</p>
        <p><strong>Invalid DIR.TAG files:</strong> $($summary.InvalidDirTags) ($(if($summary.TotalDirTags -gt 0){[Math]::Round(($summary.InvalidDirTags / $summary.TotalDirTags) * 100, 2)}else{0})%)</p>
        <p><strong>DIR.TAG files with GUID:</strong> $($summary.WithGuid) ($(if($summary.TotalDirTags -gt 0){[Math]::Round(($summary.WithGuid / $summary.TotalDirTags) * 100, 2)}else{0})%)</p>
        <p><strong>Total TODO items:</strong> $($summary.TodosTotal)</p>
        <p><strong>Completed TODO items:</strong> $($summary.TodosCompleted) ($($summary.CompletionPercentage)%)</p>

        <h3>Status Distribution</h3>
        <table>
            <tr>
                <th>Status</th>
                <th>Count</th>
                <th>Percentage</th>
            </tr>
$(
    $summary.StatusSummary | ForEach-Object {
        "<tr>
            <td class='status-$($_.Status)'>$($_.Status)</td>
            <td>$($_.Count)</td>
            <td>$($_.Percentage)%</td>
        </tr>"
    } -join "`n"
)
        </table>
    </div>

    <h2>DIR.TAG Details</h2>
    <table>
        <tr>
            <th>Path</th>
            <th>Status</th>
            <th>TODO Items</th>
            <th>Completed</th>
            <th>Has GUID</th>
            <th>Is Valid</th>
$(if ($IncludeDetails) { "            <th>Issues</th>" })
        </tr>
$(
    $report | ForEach-Object {
        "<tr>
            <td>$($_.Path)</td>
            <td class='status-$($_.Status)'>$($_.Status)</td>
            <td>$($_.TodoCount)</td>
            <td>$($_.CompletedTodos) ($(if($_.TodoCount -gt 0){[Math]::Round(($_.CompletedTodos / $_.TodoCount) * 100, 2)}else{0})%)</td>
            <td>$($_.HasGuid)</td>
            <td>$($_.IsValid)</td>
$(if ($IncludeDetails) { "            <td>$($_.Issues)</td>" })
        </tr>"
    } -join "`n"
)
    </table>

    <p><em>Generated on $(Get-Date)</em></p>
</body>
</html>
"@

        $htmlContent | Set-Content -Path $OutputFile
        Write-Host "Report saved to $OutputFile" -ForegroundColor Green
    }
    default { # Console output
        Write-Host "`nDIR.TAG Report Summary" -ForegroundColor Cyan
        Write-Host "======================" -ForegroundColor Cyan

        Write-Host "Total DIR.TAG files: $($summary.TotalDirTags)" -ForegroundColor Cyan
        Write-Host "Valid DIR.TAG files: $($summary.ValidDirTags) ($(if($summary.TotalDirTags -gt 0){[Math]::Round(($summary.ValidDirTags / $summary.TotalDirTags) * 100, 2)}else{0})%)" -ForegroundColor $(if ($summary.InvalidDirTags -eq 0) { "Green" } else { "Yellow" })
        Write-Host "Invalid DIR.TAG files: $($summary.InvalidDirTags) ($(if($summary.TotalDirTags -gt 0){[Math]::Round(($summary.InvalidDirTags / $summary.TotalDirTags) * 100, 2)}else{0})%)" -ForegroundColor $(if ($summary.InvalidDirTags -gt 0) { "Red" } else { "Green" })
        Write-Host "DIR.TAG files with GUID: $($summary.WithGuid) ($(if($summary.TotalDirTags -gt 0){[Math]::Round(($summary.WithGuid / $summary.TotalDirTags) * 100, 2)}else{0})%)" -ForegroundColor $(if ($summary.WithGuid -lt $summary.TotalDirTags) { "Yellow" } else { "Green" })

        Write-Host "`nTODO Completion" -ForegroundColor Cyan
        Write-Host "Total TODO items: $($summary.TodosTotal)" -ForegroundColor Cyan
        Write-Host "Completed TODO items: $($summary.TodosCompleted) ($($summary.CompletionPercentage)%)" -ForegroundColor $(
            if ($summary.CompletionPercentage -ge 80) { "Green" }
            elseif ($summary.CompletionPercentage -ge 50) { "Yellow" }
            else { "Red" }
        )

        Write-Host "`nStatus Distribution" -ForegroundColor Cyan
        $summary.StatusSummary | ForEach-Object {
            $colorMap = @{
                'NOT_STARTED' = 'Gray'
                'PARTIALLY_COMPLETE' = 'Yellow'
                'DONE' = 'Green'
                'OUTSTANDING' = 'Red'
                'Unknown' = 'Magenta'
            }

            $color = if ($colorMap.ContainsKey($_.Status)) { $colorMap[$_.Status] } else { "White" }
            Write-Host "  $($_.Status): $($_.Count) ($($_.Percentage)%)" -ForegroundColor $color
        }

        if ($IncludeDetails) {
            Write-Host "`nDIR.TAG Details" -ForegroundColor Cyan
            $report | Format-Table -Property Path, Status, TodoCount, CompletedTodos, HasGuid, IsValid
        }
    }
}

Write-Host "DIR.TAG report generation complete." -ForegroundColor Green
