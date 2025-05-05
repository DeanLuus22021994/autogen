# Script to quickly toggle markdown linting on/off

<#
.SYNOPSIS
    Toggles markdown linting on or off and compares .github directory with origin.
.DESCRIPTION
    Provides a simple interface to enable or disable markdown linting
    by updating VS Code settings or the configuration file.
    Also provides functionality to compare local .github directory with origin.
.PARAMETER Enable
    Enables linting if specified. Cannot be used with -Disable.
.PARAMETER Disable
    Disables linting if specified. Cannot be used with -Enable.
.PARAMETER Status
    Shows the current linting status without changing anything.
.PARAMETER Compare
    Compares the local .github directory with origin and shows metrics.
.PARAMETER Detailed
    Shows detailed information about changes when used with -Compare.
.EXAMPLE
    .\Toggle-MarkdownLinting.ps1 -Disable
    Turns off markdown linting.
.EXAMPLE
    .\Toggle-MarkdownLinting.ps1 -Enable
    Turns on markdown linting.
.EXAMPLE
    .\Toggle-MarkdownLinting.ps1 -Status
    Shows the current markdown linting status.
.EXAMPLE
    .\Toggle-MarkdownLinting.ps1 -Compare
    Shows git comparison metrics between local and origin for .github directory.
.EXAMPLE
    .\Toggle-MarkdownLinting.ps1 -Compare -Detailed
    Shows detailed git comparison between local and origin for .github directory.
#>
[CmdletBinding(DefaultParameterSetName = 'Toggle')]
param(
    [Parameter(ParameterSetName = 'Enable', Mandatory = $false)]
    [switch]$Enable,

    [Parameter(ParameterSetName = 'Disable', Mandatory = $false)]
    [switch]$Disable,

    [Parameter(ParameterSetName = 'Status', Mandatory = $false)]
    [switch]$Status,

    [Parameter(ParameterSetName = 'Compare', Mandatory = $false)]
    [switch]$Compare,

    [Parameter(ParameterSetName = 'Compare', Mandatory = $false)]
    [switch]$Detailed
)

# Get the directory of the current script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Import helper module if it exists
$helperModulePath = Join-Path -Path $scriptPath -ChildPath "MarkdownLintHelpers.psm1"
if (Test-Path -Path $helperModulePath) {
    Import-Module -Name $helperModulePath -Force
    Write-Verbose "Imported helper module: $helperModulePath"
}

function Get-LintingStatus {
    [CmdletBinding()]
    param()

    $vscodeSettingsPath = Join-Path -Path $repoRoot -ChildPath ".vscode\settings.json"

    if (-not (Test-Path -Path $vscodeSettingsPath)) {
        return @{
            Enabled = $true  # Default to enabled if there's no settings file
            InSettings = $false
        }
    }

    try {
        $settings = Get-Content -Path $vscodeSettingsPath -Raw | ConvertFrom-Json -ErrorAction Stop

        # Check if markdownlint.enabled property exists and is not null
        if (Get-Member -InputObject $settings -Name "markdownlint.enabled" -MemberType NoteProperty) {
            return @{
                Enabled = [bool]$settings."markdownlint.enabled"
                InSettings = $true
            }
        }
        else {
            return @{
                Enabled = $true  # Default to enabled if property doesn't exist
                InSettings = $false
            }
        }
    }
    catch {
        Write-Warning "Error reading VS Code settings: $_"
        return @{
            Enabled = $true  # Default to enabled on error
            InSettings = $false
        }
    }
}

function Set-LintingStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )

    $vscodeDir = Join-Path -Path $repoRoot -ChildPath ".vscode"
    $vscodeSettingsPath = Join-Path -Path $vscodeDir -ChildPath "settings.json"

    # Create .vscode directory if it doesn't exist
    if (-not (Test-Path -Path $vscodeDir)) {
        New-Item -Path $vscodeDir -ItemType Directory -Force | Out-Null
    }

    # Create settings.json if it doesn't exist
    if (-not (Test-Path -Path $vscodeSettingsPath)) {
        Set-Content -Path $vscodeSettingsPath -Value "{}" -Force
    }

    try {
        $settings = Get-Content -Path $vscodeSettingsPath -Raw | ConvertFrom-Json

        # Create a PSCustomObject if settings is null
        if ($null -eq $settings) {
            $settings = [PSCustomObject]@{}
        }

        # Add or update markdownlint.enabled property
        $settings | Add-Member -MemberType NoteProperty -Name "markdownlint.enabled" -Value $Enabled -Force

        # Save settings back to file
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $vscodeSettingsPath -Force

        return $true
    }
    catch {
        Write-Error "Failed to update VS Code settings: $_"
        return $false
    }
}

function Show-LintingStatus {
    [CmdletBinding()]
    param()

    $status = Get-LintingStatus

    if ($status.Enabled) {
        Write-Host "Markdown linting is currently ENABLED." -ForegroundColor Green
    }
    else {
        Write-Host "Markdown linting is currently DISABLED." -ForegroundColor Yellow
    }

    if (-not $status.InSettings) {
        Write-Host "Note: This is the default setting as no explicit configuration was found." -ForegroundColor Cyan
    }

    # Check if VS Code extension is installed
    try {
        $extensions = Invoke-Expression "code --list-extensions" -ErrorAction SilentlyContinue
        if ($extensions -contains "DavidAnson.vscode-markdownlint") {
            Write-Host "VS Code markdownlint extension is installed." -ForegroundColor Green
        }
        else {
            Write-Warning "VS Code markdownlint extension is not installed. Install it for better integration."
        }
    }
    catch {
        Write-Verbose "Could not check VS Code extensions: $_"
    }
}

function Test-GitAvailable {
    [CmdletBinding()]
    param()

    try {
        $null = & git --version 2>&1
        return $true
    }
    catch {
        return $false
    }
}

function Test-GitRepository {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        Push-Location $Path
        $isGitRepo = (& git rev-parse --is-inside-work-tree 2>&1) -eq 'true'
        Pop-Location
        return $isGitRepo
    }
    catch {
        if ($null -ne (Get-Location).Path) {
            Pop-Location
        }
        return $false
    }
}

function Get-GitHubDirectoryChanges {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )

    if (-not (Test-GitAvailable)) {
        Write-Error "Git is not available. Please ensure Git is installed and available in PATH."
        return $null
    }

    if (-not (Test-GitRepository -Path $Path)) {
        Write-Error "The directory '$Path' is not a Git repository or is not inside a Git repository."
        return $null
    }

    try {
        Push-Location $Path

        # Ensure we have the latest from origin
        try {
            Write-Verbose "Fetching latest changes from origin..."
            & git fetch origin 2>&1 | Out-Null
        }
        catch {
            Write-Warning "Could not fetch from origin: $_"
            # Continue with local information only
        }

        # Get the current branch
        $currentBranch = & git branch --show-current
        if ([string]::IsNullOrEmpty($currentBranch)) {
            $currentBranch = "HEAD"
        }

        Write-Verbose "Current branch: $currentBranch"

        # Get the .github directory path relative to repository root
        $repoRoot = & git rev-parse --show-toplevel
        $githubDir = ".github"
        $githubPath = Join-Path -Path $repoRoot -ChildPath $githubDir

        if (-not (Test-Path -Path $githubPath)) {
            Write-Error "The .github directory does not exist in this repository."
            Pop-Location
            return $null
        }

        # Get changes between origin and local for .github directory
        $gitCommand = "git diff --name-status origin/$currentBranch...$currentBranch -- $githubDir"
        $changedFiles = Invoke-Expression $gitCommand

        # Get detailed diff stats if requested
        $diffStats = $null
        if ($Detailed) {
            $gitStatsCommand = "git diff --stat origin/$currentBranch...$currentBranch -- $githubDir"
            $diffStats = Invoke-Expression $gitStatsCommand
        }

        # Get summary metrics
        $gitSummaryCommand = "git diff --shortstat origin/$currentBranch...$currentBranch -- $githubDir"
        $summary = Invoke-Expression $gitSummaryCommand

        # Process changed files into structured format
        $changes = @()
        foreach ($change in $changedFiles) {
            if (-not [string]::IsNullOrWhiteSpace($change)) {
                $parts = $change -split "\s+", 2
                if ($parts.Count -ge 2) {
                    $changeType = $parts[0]
                    $filePath = $parts[1]

                    $changeTypeDesc = switch($changeType) {
                        "A" { "Added" }
                        "M" { "Modified" }
                        "D" { "Deleted" }
                        "R" { "Renamed" }
                        "C" { "Copied" }
                        "U" { "Unmerged" }
                        default { $changeType }
                    }

                    # Create relative path from repository root
                    $relativePath = $filePath

                    $changes += [PSCustomObject]@{
                        ChangeType = $changeTypeDesc
                        FilePath = $filePath
                        RelativePath = $relativePath
                    }
                }
            }
        }

        Pop-Location

        return [PSCustomObject]@{
            Changes = $changes
            Summary = $summary
            DetailedStats = $diffStats
            Branch = $currentBranch
        }
    }
    catch {
        Write-Error "Error comparing Git directories: $_"
        if ($null -ne (Get-Location).Path) {
            Pop-Location
        }
        return $null
    }
}

function Show-GitHubChanges {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )

    # Use the improved function that already exists
    Show-GitHubChanges -Detailed:$Detailed
}

function Show-GitHubChanges {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )

    $githubPath = Join-Path -Path $repoRoot -ChildPath ".github"

    if (-not (Test-Path -Path $githubPath)) {
        Write-Warning "The .github directory does not exist in this repository."
        return
    }

    Write-Host "Comparing local .github directory with origin..." -ForegroundColor Cyan

    # Generate metrics for .github directory structure first
    $dirMetrics = Get-DirectoryMetrics -Path $githubPath

    # Get Git changes data second
    $changes = Get-GitHubDirectoryChanges -Path $repoRoot -Detailed:$Detailed

    # Create comprehensive metrics object that combines directory metrics and git changes
    $comprehensiveMetrics = [PSCustomObject]@{
        DirectoryMetrics = [PSCustomObject]@{
            TotalDirectories = $dirMetrics.TotalDirectories
            TotalFiles = $dirMetrics.TotalFiles
            TotalSizeKB = [Math]::Round($dirMetrics.TotalSizeKB, 2)
            FileExtensionBreakdown = $dirMetrics.FileTypes | Sort-Object -Property Count -Descending
        }
        GitChanges = if ($null -eq $changes) {
            [PSCustomObject]@{
                Status = "No Git comparison data available"
            }
        } else {
            [PSCustomObject]@{
                Branch = $changes.Branch
                TotalChanges = $changes.Changes.Count
                Added = ($changes.Changes | Where-Object { $_.ChangeType -eq "Added" }).Count
                Modified = ($changes.Changes | Where-Object { $_.ChangeType -eq "Modified" }).Count
                Deleted = ($changes.Changes | Where-Object { $_.ChangeType -eq "Deleted" }).Count
                ChangedFiles = @($changes.Changes | ForEach-Object {
                    [PSCustomObject]@{
                        Type = $_.ChangeType
                        Path = $_.FilePath
                        RelativePath = $_.RelativePath
                    }
                })
                Summary = $changes.Summary
            }
        }
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ExecutionInfo = [PSCustomObject]@{
            User = [Environment]::UserName
            Computer = [Environment]::MachineName
            OSVersion = [Environment]::OSVersion.VersionString
            PSVersion = $PSVersionTable.PSVersion.ToString()
        }
    }
      # Convert to machine-readable format
    if ($Detailed) {
        $jsonOutput = $comprehensiveMetrics | ConvertTo-Json -Depth 5
    } else {
        # Create a simplified view for non-detailed mode
        $simplifiedMetrics = [PSCustomObject]@{
            DirectoryMetrics = $comprehensiveMetrics.DirectoryMetrics
            GitChanges = if ($comprehensiveMetrics.GitChanges.Status) {
                $comprehensiveMetrics.GitChanges.Status
            } else {
                [PSCustomObject]@{
                    Branch = $comprehensiveMetrics.GitChanges.Branch
                    TotalChanges = $comprehensiveMetrics.GitChanges.TotalChanges
                    Added = $comprehensiveMetrics.GitChanges.Added
                    Modified = $comprehensiveMetrics.GitChanges.Modified
                    Deleted = $comprehensiveMetrics.GitChanges.Deleted
                }
            }
            Timestamp = $comprehensiveMetrics.Timestamp
        }
        $jsonOutput = $simplifiedMetrics | ConvertTo-Json -Depth 3 -Compress
    }

    # Display machine-readable metrics
    Write-Host "`n----- Machine-Readable Directory Metrics and Git Changes -----" -ForegroundColor Cyan
    Write-Host "MACHINE_READABLE_METRICS_START" -ForegroundColor DarkGray
    Write-Host $jsonOutput -ForegroundColor White
    Write-Host "MACHINE_READABLE_METRICS_END" -ForegroundColor DarkGray
        # Create a simplified view for non-detailed mode
        $simplifiedMetrics = [PSCustomObject]@{
            DirectoryMetrics = $comprehensiveMetrics.DirectoryMetrics
            GitChanges = if ($comprehensiveMetrics.GitChanges.Status) {
                $comprehensiveMetrics.GitChanges.Status
            } else {
                [PSCustomObject]@{
                    Branch = $comprehensiveMetrics.GitChanges.Branch
                    TotalChanges = $comprehensiveMetrics.GitChanges.TotalChanges
                    Added = $comprehensiveMetrics.GitChanges.Added
                    Modified = $comprehensiveMetrics.GitChanges.Modified
                    Deleted = $comprehensiveMetrics.GitChanges.Deleted
                }
            }
            Timestamp = $comprehensiveMetrics.Timestamp
        }
        $jsonOutput = $simplifiedMetrics | ConvertTo-Json -Depth 3 -Compress
    }

    # Display machine-readable metrics
    Write-Host "`n----- Machine-Readable Directory Metrics and Git Changes -----" -ForegroundColor Cyan
    Write-Host "MACHINE_READABLE_METRICS_START" -ForegroundColor DarkGray
    Write-Host $jsonOutput -ForegroundColor White
    Write-Host "MACHINE_READABLE_METRICS_END" -ForegroundColor DarkGray

    # Display human-readable summary of directory metrics
    Write-Host "`n----- Directory Statistics -----" -ForegroundColor Cyan
    Write-Host "Total directories: $($dirMetrics.TotalDirectories)" -ForegroundColor White
    Write-Host "Total files: $($dirMetrics.TotalFiles)" -ForegroundColor White
    Write-Host "Total size: $([Math]::Round($dirMetrics.TotalSizeKB, 2)) KB" -ForegroundColor White

    # Display file extension breakdown
    Write-Host "`n----- File Extension Breakdown -----" -ForegroundColor Cyan
    $dirMetrics.FileTypes | Sort-Object -Property Count -Descending | ForEach-Object {
        Write-Host "$($_.Extension): $($_.Count) files" -ForegroundColor White
    }

    # If there are no changes, display appropriate message and exit
    if ($null -eq $changes) {
        Write-Host "`nNo Git comparison data available." -ForegroundColor Yellow
        return
    }

    if ($changes.Changes.Count -eq 0) {
        Write-Host "`nNo differences found between local and origin for .github directory." -ForegroundColor Green
        return
    }

    # Display git change summary
    Write-Host "`n----- Git Change Summary -----" -ForegroundColor Cyan
    if ([string]::IsNullOrWhiteSpace($changes.Summary)) {
        Write-Host "No summary statistics available." -ForegroundColor Yellow
    } else {
        Write-Host $changes.Summary -ForegroundColor White
    }

    # Display changes
    Write-Host "`n----- Changed Files -----" -ForegroundColor Cyan
    $changes.Changes | ForEach-Object {
        $color = switch($_.ChangeType) {
            "Added" { "Green" }
            "Modified" { "Yellow" }
            "Deleted" { "Red" }
            default { "White" }
        }

        Write-Host "$($_.ChangeType): " -NoNewline -ForegroundColor $color
        Write-Host "$($_.FilePath)" -ForegroundColor White
    }

    # Display detailed git statistics if requested
    if ($Detailed -and -not [string]::IsNullOrWhiteSpace($changes.DetailedStats)) {
        Write-Host "`n----- Detailed Git Statistics -----" -ForegroundColor Cyan
        Write-Host $changes.DetailedStats -ForegroundColor White
    }

    # Display implementation metrics
    $addCount = ($changes.Changes | Where-Object { $_.ChangeType -eq "Added" }).Count
    $modCount = ($changes.Changes | Where-Object { $_.ChangeType -eq "Modified" }).Count
    $delCount = ($changes.Changes | Where-Object { $_.ChangeType -eq "Deleted" }).Count

    Write-Host "`n----- Implementation Metrics -----" -ForegroundColor Cyan
    Write-Host "Current Branch: " -NoNewline
    Write-Host "$($changes.Branch)" -ForegroundColor White
    Write-Host "Files Added: " -NoNewline
    Write-Host "$addCount" -ForegroundColor $(if ($addCount -gt 0) { "Green" } else { "White" })
    Write-Host "Files Modified: " -NoNewline
    Write-Host "$modCount" -ForegroundColor $(if ($modCount -gt 0) { "Yellow" } else { "White" })
    Write-Host "Files Deleted: " -NoNewline
    Write-Host "$delCount" -ForegroundColor $(if ($delCount -gt 0) { "Red" } else { "White" })
}

function Get-DirectoryMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Initialize script-scoped variables to track metrics
    $script:totalFiles = 0
    $script:totalSizeBytes = 0
    $script:totalDirectories = 1  # Start with 1 for the root directory
    $script:filesByType = @{}

    # Function to process a directory recursively
    function Invoke-DirectoryProcessing {
        param (
            [string]$DirPath,
            [string]$RelativePath,
            [hashtable]$Tree
        )

        $dirInfo = @{
            Path = $RelativePath
            Files = @()
            Directories = @{}
            FileCount = 0
            TotalSizeKB = 0
        }

        # Process files in this directory
        $files = Get-ChildItem -Path $DirPath -File
        foreach ($file in $files) {
            $script:totalFiles++
            $script:totalSizeBytes += $file.Length

            # Track files by extension
            $extension = if ([string]::IsNullOrEmpty($file.Extension)) { "(no extension)" } else { $file.Extension }
            if (-not $script:filesByType.ContainsKey($extension)) {
                $script:filesByType[$extension] = 0
            }
            $script:filesByType[$extension]++

            # Add file to directory info
            $dirInfo.Files += @{
                Name = $file.Name
                SizeKB = [Math]::Round($file.Length / 1KB, 2)
                Extension = $extension
                LastModified = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }

            $dirInfo.FileCount++
            $dirInfo.TotalSizeKB += ($file.Length / 1KB)
        }

        # Process subdirectories
        $subdirs = Get-ChildItem -Path $DirPath -Directory
        foreach ($subdir in $subdirs) {
            $script:totalDirectories++
            $subRelPath = if ($RelativePath) { "$RelativePath/$($subdir.Name)" } else { $subdir.Name }
            $dirInfo.Directories[$subdir.Name] = @{}
            Invoke-DirectoryProcessing -DirPath $subdir.FullName -RelativePath $subRelPath -Tree $dirInfo.Directories[$subdir.Name]
        }

        # Update tree with directory info
        foreach ($key in $dirInfo.Keys) {
            $Tree[$key] = $dirInfo[$key]
        }
    }
      # Process root directory
    $rootTree = @{}
    Invoke-DirectoryProcessing -DirPath $Path -RelativePath (Split-Path -Leaf $Path) -Tree $rootTree

    # Convert file type counts to array for easier JSON processing
    $fileTypeStats = @()
    foreach ($ext in $script:filesByType.Keys) {
        $fileTypeStats += @{
            Extension = $ext
            Count = $script:filesByType[$ext]
        }
    }

    # Create metrics object with proper scoping
    $metrics = [PSCustomObject]@{
        RootPath = $Path
        TotalFiles = $script:totalFiles
        TotalDirectories = $script:totalDirectories
        TotalSizeKB = [Math]::Round($script:totalSizeBytes / 1KB, 2)
        FileTypes = $fileTypeStats
        DirectoryTree = $rootTree
    }

    return $metrics
}

    # Convert file type counts to array for easier JSON processing
    $fileTypeStats = @()
    foreach ($ext in $script:filesByType.Keys) {
        $fileTypeStats += @{
            Extension = $ext
            Count = $script:filesByType[$ext]
        }
    }

    # Create metrics object with proper scoping
    $metrics = [PSCustomObject]@{
        RootPath = $Path
        TotalFiles = $script:totalFiles
        TotalDirectories = $script:totalDirectories
        TotalSizeKB = [Math]::Round($script:totalSizeBytes / 1KB, 2)
        FileTypes = $fileTypeStats
        DirectoryTree = $rootTree
    }

    return $metrics
}

# Main execution
try {
    if ($Status) {
        Show-LintingStatus
    }
    elseif ($Enable) {
        $result = Set-LintingStatus -Enabled $true
        if ($result) {
            Write-Host "Markdown linting has been ENABLED." -ForegroundColor Green
        }
        Show-LintingStatus
    }
    elseif ($Disable) {
        $result = Set-LintingStatus -Enabled $false
        if ($result) {
            Write-Host "Markdown linting has been DISABLED." -ForegroundColor Yellow
        }
        Show-LintingStatus
    }
    elseif ($Compare) {
        Show-GitHubChanges -Detailed:$Detailed
    }
    else {
        # No parameter specified, toggle current status
        $currentStatus = Get-LintingStatus
        $newState = -not $currentStatus.Enabled
        $result = Set-LintingStatus -Enabled $newState

        if ($result) {
            if ($newState) {
                Write-Host "Markdown linting has been ENABLED." -ForegroundColor Green
            }
            else {
                Write-Host "Markdown linting has been DISABLED." -ForegroundColor Yellow
            }
        }

        Show-LintingStatus
    }
}
catch {
    Write-Error "Error toggling markdown linting: $_"
    exit 1
}