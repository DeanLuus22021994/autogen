# .github\linting\utils\FileOperations.psm1
# File operation utilities for markdown linting

<#
.SYNOPSIS
    Provides file operation utilities for markdown linting.
.DESCRIPTION
    A set of functions to handle common file operations needed for
    markdown linting processes.
#>

function Test-FileIsMarkdown {
    <#
    .SYNOPSIS
        Tests if a file is a markdown file.
    .DESCRIPTION
        Determines if a file is a markdown file based on its extension.
    .PARAMETER Path
        The path to the file to test.
    .OUTPUTS
        [bool] True if the file is a markdown file, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $extension = [System.IO.Path]::GetExtension($Path)
    return $extension -eq '.md' -or $extension -eq '.markdown'
}

function Get-FilesMatchingPattern {
    <#
    .SYNOPSIS
        Gets files matching a glob pattern.
    .DESCRIPTION
        Expands a glob pattern to a list of file paths.
    .PARAMETER Pattern
        The glob pattern to match.
    .PARAMETER BasePath
        The base path to start searching from.
    .OUTPUTS
        [string[]] Array of file paths matching the pattern
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter()]
        [string]$BasePath = $PWD
    )

    try {
        # Handle glob patterns
        if ($Pattern -match '[*?]') {
            # Convert glob to regex
            $regexPattern = "^" + [regex]::Escape($Pattern).Replace('\*', '.*').Replace('\?', '.') + "$"

            # Use Get-ChildItem with -Recurse if the pattern includes directory wildcards
            if ($Pattern -match '/\*\*/' -or $Pattern -match '\\\\*\\\\') {
                $files = Get-ChildItem -Path $BasePath -Recurse -File |
                    Where-Object { $_.FullName -match $regexPattern }
            }
            else {
                $files = Get-ChildItem -Path $BasePath -File |
                    Where-Object { $_.FullName -match $regexPattern }
            }

            return $files.FullName
        }
        else {
            # Direct file path
            $fullPath = Join-Path -Path $BasePath -ChildPath $Pattern
            if (Test-Path -Path $fullPath -PathType Leaf) {
                return $fullPath
            }
            return @()
        }
    }
    catch {
        Write-Warning "Error expanding glob pattern '$Pattern': $_"
        return @()
    }
}

function Backup-File {
    <#
    .SYNOPSIS
        Creates a backup of a file.
    .DESCRIPTION
        Saves a copy of a file with a timestamp for backup purposes.
    .PARAMETER Path
        The path to the file to backup.
    .PARAMETER BackupDirectory
        The directory where backups should be stored.
    .OUTPUTS
        [string] Path to the backup file
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string]$BackupDirectory
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "File not found: $Path"
    }

    # Generate backup path
    $fileName = [System.IO.Path]::GetFileName($Path)
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    if (-not $BackupDirectory) {
        $BackupDirectory = Join-Path -Path ([System.IO.Path]::GetDirectoryName($Path)) -ChildPath "backups"
    }

    # Ensure backup directory exists
    if (-not (Test-Path -Path $BackupDirectory)) {
        New-Item -Path $BackupDirectory -ItemType Directory -Force | Out-Null
    }

    $backupPath = Join-Path -Path $BackupDirectory -ChildPath "${fileName}.${timestamp}.bak"

    try {
        Copy-Item -Path $Path -Destination $backupPath -Force
        return $backupPath
    }
    catch {
        Write-Warning "Failed to create backup of $Path`: $_"
        return $null
    }
}

function Compare-FileContent {
    <#
    .SYNOPSIS
        Compares the content of two files.
    .DESCRIPTION
        Determines if two files have the same content.
    .PARAMETER Path1
        The path to the first file.
    .PARAMETER Path2
        The path to the second file.
    .OUTPUTS
        [bool] True if the files have the same content, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path1,

        [Parameter(Mandatory = $true)]
        [string]$Path2
    )

    if (-not (Test-Path -Path $Path1 -PathType Leaf)) {
        throw "File not found: $Path1"
    }

    if (-not (Test-Path -Path $Path2 -PathType Leaf)) {
        throw "File not found: $Path2"
    }

    try {
        $content1 = Get-Content -Path $Path1 -Raw
        $content2 = Get-Content -Path $Path2 -Raw

        return $content1 -eq $content2
    }
    catch {
        Write-Warning "Error comparing files: $_"
        return $false
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Test-FileIsMarkdown',
    'Get-FilesMatchingPattern',
    'Backup-File',
    'Compare-FileContent'
)<|cursor|>