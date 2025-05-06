# PowerShell module for integrating DirTag with problem management

function Update-DirTagStatusFromProblems {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DirectoryPath,

        [Parameter(Mandatory=$false)]
        [switch]$Force,

        [Parameter(Mandatory=$false)]
        [switch]$Recurse
    )

    # Check if the directory exists
    if (-not (Test-Path -Path $DirectoryPath -PathType Container)) {
        Write-Error "Directory not found: $DirectoryPath"
        return $false
    }

    # Import required modules if not already loaded
    $modulesToCheck = @(
        @{Name = "DirTagManagement"; Path = Join-Path -Path $PSScriptRoot -ChildPath "DirTagManagement.psm1"},
        @{Name = "ProblemManagement"; Path = Join-Path -Path $PSScriptRoot -ChildPath "ProblemManagement.psm1"}
    )

    foreach ($module in $modulesToCheck) {
        if (-not (Get-Module -Name $module.Name)) {
            if (Test-Path -Path $module.Path) {
                Import-Module $module.Path -Force -Global -Verbose
                Write-Host "Imported module: $($module.Name)" -ForegroundColor Green
            } else {
                Write-Error "Required module $($module.Name) not found at $($module.Path)"
                return $false
            }
        }
    }

    # Get problem configuration
    $problemConfig = Get-ProblemConfig
    if (-not $problemConfig) {
        Write-Warning "Problem configuration not found. Using default mappings."
        $problemConfig = @{
            problem_type = @(
                @{id = "error"; status = "OUTSTANDING"},
                @{id = "warning"; status = "PARTIALLY_COMPLETE"},
                @{id = "info"; status = "NOT_STARTED"}
            )
        }
    }    # Get DIR.TAG file path
    $dirTagPath = Join-Path -Path $DirectoryPath -ChildPath "DIR.TAG"

    # Check if DIR.TAG exists
    if (-not (Test-Path -Path $dirTagPath)) {
        if ($Force) {
            # Create new DIR.TAG file if forced
            New-DirTag -DirectoryPath $DirectoryPath -Force
        } else {
            Write-Warning "DIR.TAG not found at $DirectoryPath and -Force not specified."
            return $false
        }
    }

    # Get problems in the directory
    $problems = Get-DirectoryProblems -DirectoryPath $DirectoryPath

    # Determine status based on problems
    $status = "DONE" # Default to DONE if no problems found

    # Check for the most severe problem type
    $severityOrder = @("error", "warning", "info")
    $problemTypes = $problems | ForEach-Object { $_.Type } | Sort-Object -Unique

    foreach ($severity in $severityOrder) {
        if ($problemTypes -contains $severity) {
            # Find the corresponding status in the problem configuration
            $matchingConfig = $problemConfig.problem_type | Where-Object { $_.id -eq $severity -or $_.n -eq $severity }
            if ($matchingConfig) {
                $status = $matchingConfig.status
                break # Found the most severe problem, exit the loop
            }
        }
    }

    # Update DIR.TAG status
    $dirTag = Get-DirTag -Path $dirTagPath
    if ($dirTag) {
        $dirTag.status = $status
        $dirTag.updated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

        # Update the todo list based on problems
        $todoItems = @()

        # Group problems by type for better organization
        $problemsByType = $problems | Group-Object -Property Type

        foreach ($group in $problemsByType) {
            $todoStatus = switch ($group.Name) {
                "error" { "OUTSTANDING" }
                "warning" { "IN_PROGRESS" }
                default { "NOT_STARTED" }
            }

            foreach ($problem in $group.Group) {
                $todoMessage = "Fix $($problem.Type) in $($problem.FilePath | Split-Path -Leaf): $($problem.Message)"
                $todoItems += "$todoMessage [$todoStatus]"
            }
        }

        # Only update TODO items if we have problems
        if ($todoItems.Count -gt 0) {
            $dirTag.TODO = $todoItems
        }

        # Save updated DIR.TAG
        $dirTag | Set-DirTag -Path $dirTagPath

        Write-Host "Updated DIR.TAG status to $status for $DirectoryPath" -ForegroundColor Green
    } else {
        Write-Error "Failed to read DIR.TAG at $dirTagPath"
        return $false
    }

    # Process subdirectories if recurse is specified
    if ($Recurse) {
        $subdirectories = Get-ChildItem -Path $DirectoryPath -Directory
        foreach ($subdir in $subdirectories) {
            Update-DirTagStatusFromProblems -DirectoryPath $subdir.FullName -Force:$Force -Recurse
        }
    }

    return $true
}

# Alias for update to match naming in tests and scripts
function Update-DirTagFromProblems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$DirectoryPath,
        [Parameter(Mandatory=$false)] [switch]$Force,
        [Parameter(Mandatory=$false)] [switch]$Recurse
    )
    return Update-DirTagStatusFromProblems -DirectoryPath $DirectoryPath -Force:$Force -Recurse:$Recurse
}

function Get-DirTagProblemSummary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$RootPath,

        [Parameter(Mandatory=$false)]
        [string]$OutputFormat = "Table" # Table, JSON, CSV
    )

    # Import required modules if not already loaded
    $modulesToCheck = @(
        @{Name = "DirTagManagement"; Path = Join-Path -Path $PSScriptRoot -ChildPath "DirTagManagement.psm1"},
        @{Name = "ProblemManagement"; Path = Join-Path -Path $PSScriptRoot -ChildPath "ProblemManagement.psm1"}
    )

    foreach ($module in $modulesToCheck) {
        if (-not (Get-Module -Name $module.Name)) {
            if (Test-Path -Path $module.Path) {
                Import-Module $module.Path -Force
            } else {
                Write-Error "Required module $($module.Name) not found at $($module.Path)"
                return $null
            }
        }
    }

    # Get all DIR.TAG files
    $dirTagFiles = Get-ChildItem -Path $RootPath -Filter "DIR.TAG" -Recurse -File

    $summary = @()    foreach ($file in $dirTagFiles) {
        $dirPath = Split-Path -Path $file.FullName -Parent
        # Not using dirName but keeping for future reference
        # $dirName = Split-Path -Path $dirPath -Leaf
        $relativePath = $dirPath.Substring($RootPath.Length).TrimStart('\', '/')
        if ($relativePath -eq "") { $relativePath = "." }

        # Get DIR.TAG data
        $dirTag = Get-DirTag -Path $file.FullName

        # Get problems in the directory
        $problems = Get-DirectoryProblems -DirectoryPath $dirPath

        # Count problems by type
        $errorCount = ($problems | Where-Object { $_.Type -eq "error" }).Count
        $warningCount = ($problems | Where-Object { $_.Type -eq "warning" }).Count
        $infoCount = ($problems | Where-Object { $_.Type -eq "info" }).Count

        # Create summary item
        $summaryItem = [PSCustomObject]@{
            Path = $relativePath
            Status = $dirTag.status
            ErrorCount = $errorCount
            WarningCount = $warningCount
            InfoCount = $infoCount
            TotalProblems = $problems.Count
            LastUpdated = $dirTag.updated
            GUID = $dirTag.GUID
        }

        $summary += $summaryItem
    }

    # Format and output the summary
    switch ($OutputFormat) {
        "JSON" {
            return $summary | ConvertTo-Json
        }
        "CSV" {
            return $summary | ConvertTo-Csv -NoTypeInformation
        }
        default {
            return $summary | Format-Table -AutoSize
        }
    }
}

# Export functions
Export-ModuleMember -Function Update-DirTagStatusFromProblems, Get-DirTagProblemSummary
