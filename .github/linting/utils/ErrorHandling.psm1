# .github/linting/utils/FileOperations.psm1
# File operations for markdown linting

function Test-PathExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [switch]$Create,

        [Parameter(Mandatory = $false)]
        [ValidateSet('File', 'Directory')]
        [string]$ItemType = 'File'
    )

    $exists = Test-Path -Path $Path

    if (-not $exists -and $Create) {
        if ($ItemType -eq 'Directory') {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }
        else {
            $directory = Split-Path -Path $Path -Parent
            if (-not (Test-Path -Path $directory)) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }
            New-Item -Path $Path -ItemType File -Force | Out-Null
        }
        $exists = $true
    }

    return $exists
}

function Copy-ConfigFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    $destExists = Test-Path -Path $Destination

    if ($destExists -and -not $Force) {
        Write-Verbose "File $Destination already exists. Use -Force to overwrite."
        return $false
    }

    try {
        Copy-Item -Path $Source -Destination $Destination -Force:$Force
        return $true
    }
    catch {
        Write-Error "Failed to copy file from $Source to $Destination: $_"
        return $false
    }
}

function Get-RepositoryRoot {
    [CmdletBinding()]
    param()

    $currentPath = Get-Location

    while ($currentPath -ne "") {
        if (Test-Path -Path (Join-Path -Path $currentPath -ChildPath ".git")) {
            return $currentPath
        }

        $parentPath = Split-Path -Path $currentPath -Parent
        if ($parentPath -eq $currentPath) {
            break
        }

        $currentPath = $parentPath
    }

    throw "Unable to find repository root. Are you in a Git repository?"
}

Export-ModuleMember -Function Test-PathExists, Copy-ConfigFile, Get-RepositoryRoot