# .github/linting/utils/ErrorHandling.psm1
# Error handling utilities for markdown linting

using namespace System.Management.Automation

function Write-LintError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory = $false)]
        [switch]$Fatal
    )

    $errorDetails = if ($ErrorRecord) {
        " Error details: $($ErrorRecord.Exception.Message)"
    } else {
        ""
    }

    Write-Host "ERROR: $Message$errorDetails" -ForegroundColor Red

    if ($Fatal) {
        throw [System.Management.Automation.RuntimeException]::new($Message)
    }
}

function Test-CommandExecution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,

        [Parameter(Mandatory = $false)]
        [switch]$ContinueOnError
    )

    try {
        & $ScriptBlock
        return $true
    }
    catch {
        Write-LintError -Message $ErrorMessage -ErrorRecord $_ -Fatal:(-not $ContinueOnError)
        return $false
    }
}

# Helper function to format error messages
function Get-FormattedErrorMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory = $false)]
        [string]$Context
    )

    $contextInfo = if ($Context) {
        " while $Context"
    } else {
        ""
    }

    return "Error$contextInfo`: $($ErrorRecord.Exception.Message)"
}

Export-ModuleMember -Function Write-LintError, Test-CommandExecution, Get-FormattedErrorMessage
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