<#
.SYNOPSIS
    Cleans up DIR.TAG files across the repository to follow standardized format.
.DESCRIPTION
    This script scans the repository for DIR.TAG files and ensures they follow
    the standardized format defined in the project guidelines. It removes
    comments, standardizes formatting, and updates timestamps as needed.
    Special handling is provided for DevContainer directories to ensure proper
    Docker Model Runner integration.
.PARAMETER Force
    If specified, forces update of all DIR.TAG files, even if they already
    conform to the standard.
.PARAMETER CheckDevContainer
    If specified, performs additional validation for DevContainer-specific requirements.
.EXAMPLE
    .\Cleanup-DirTagFiles.ps1 -Force -CheckDevContainer
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$Force = $false,

    [Parameter(Mandatory = $false)]
    [switch]$CheckDevContainer = $false
)

# Import required modules
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "modules\DirTagManagement.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Warning "DirTagManagement module not found at $modulePath. Some functionality may be limited."
}

function Get-DirTagFiles {
    $repoRoot = (Get-Item $PSScriptRoot).Parent.FullName
    $dirTagFiles = Get-ChildItem -Path $repoRoot -Recurse -Filter "DIR.TAG" |
                  Where-Object { -not $_.FullName.Contains(".git") }
    return $dirTagFiles
}

function Test-IsDevContainerPath {
    param (
        [string]$FilePath
    )

    # Check if the path contains .devcontainer
    return $FilePath -match "[\\/]\.devcontainer[\\/]"
}

function Test-IsInContainer {
    # Check if running inside a container
    return (Test-Path "/.dockerenv") -or (Test-Path "/run/.containerenv")
}

function Test-DirTagFormat {
    param (
        [string]$Content,
        [bool]$IsDevContainer = $false
    )

    # Check if the content starts with a comment line
    if ($Content -match "^//") {
        return $false
    }

    # Check if the content starts with the INDEX line
    if (-not ($Content -match "^#INDEX:")) {
        return $false
    }

    # For DevContainer DIR.TAG files, check for Docker Model Runner integration if required
    if ($IsDevContainer -and $CheckDevContainer) {
        if (-not ($Content -match "Docker Model Runner")) {
            return $false
        }
    }

    return $true
}

function Convert-ToRelativePath {
    param (
        [string]$AbsolutePath,
        [string]$BasePath
    )

    # Handle path separators consistently
    $normalizedAbsPath = $AbsolutePath.Replace('\', '/')
    $normalizedBasePath = $BasePath.Replace('\', '/')

    # Remove the base path to get the relative path
    $relativePath = $normalizedAbsPath.Replace($normalizedBasePath, "").TrimStart('/')

    # Handle root directory case
    if ([string]::IsNullOrWhiteSpace($relativePath)) {
        return "."
    }

    return $relativePath
}

function Update-DirTagFormat {
    param (
        [string]$FilePath
    )

    $content = Get-Content -Path $FilePath -Raw
    $isDevContainer = Test-IsDevContainerPath -FilePath $FilePath
    $repoRoot = (Get-Item $PSScriptRoot).Parent.FullName

    # Remove leading comments
    $content = $content -replace "(?m)^//.*?$", ""

    # Ensure the file starts with #INDEX
    if (-not ($content -match "^#INDEX:")) {
        $dirPath = Split-Path -Parent $FilePath
        $relativePath = Convert-ToRelativePath -AbsolutePath $dirPath -BasePath $repoRoot
        $content = "#INDEX: $relativePath`n$content"
    }

    # Ensure there's a status line
    if (-not ($content -match "status:")) {
        $content += "`nstatus: NOT_STARTED"
    }

    # Ensure there's an updated timestamp
    $timestamp = Get-Date -Format "o"
    if ($content -match "updated:") {
        $content = $content -replace "updated:.*", "updated: $timestamp"
    } else {
        $content += "`nupdated: $timestamp"
    }

    # For DevContainer directories, ensure Docker Model Runner integration is mentioned
    if ($isDevContainer -and $CheckDevContainer) {
        if (-not ($content -match "Docker Model Runner")) {
            $dockerModelRunnerInfo = @"

# Docker Model Runner Integration
- Configuration for Docker Model Runner in DevContainer setup
- Integration with local AI models (ai/mistral, ai/mistral-nemo, etc.)
- Persistent volume configuration for model storage
"@
            # Add the Docker Model Runner information to the description section
            if ($content -match "description: \|") {
                $content = $content -replace "(description: \|.*?)(\r?\n[a-zA-Z#])", "`$1$dockerModelRunnerInfo`$2"
            } else {
                $content += "`ndescription: |`n  DevContainer configuration.$dockerModelRunnerInfo"
            }
        }
    }

    # Format the content
    $content = $content.Trim()

    # Set proper line endings based on platform
    $content = $content.Replace("`r`n", "`n")

    # Write updated content back to file using UTF-8 encoding without BOM
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($FilePath, $content, $utf8NoBomEncoding)

    return $content
}

function Test-DockerModelRunnerAvailable {
    try {
        # Check if docker is available
        $dockerInfo = docker info 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        # Check for Docker Desktop 4.40+ (required for Docker Model Runner)
        $dockerVersion = docker version --format '{{.Server.Version}}' 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        if ([Version]$dockerVersion -lt [Version]"4.40.0") {
            return $false
        }

        # Check if Docker Model Runner is available
        $dockerModelRunnerInfo = docker model ls 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        return $true
    } catch {
        return $false
    }
}

# Main script
$dirTagFiles = Get-DirTagFiles
$updatedCount = 0
$devContainerCount = 0

# Check Docker Model Runner availability if checking DevContainer
$dockerModelRunnerAvailable = $false
if ($CheckDevContainer) {
    $dockerModelRunnerAvailable = Test-DockerModelRunnerAvailable
    if (-not $dockerModelRunnerAvailable) {
        Write-Warning "Docker Model Runner is not available. Ensure Docker Desktop 4.40+ is installed and Model Runner is enabled."
    } else {
        Write-Host "Docker Model Runner is available. DevContainer DIR.TAG files will be updated with Model Runner integration information." -ForegroundColor Green
    }
}

foreach ($file in $dirTagFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $isDevContainer = Test-IsDevContainerPath -FilePath $file.FullName

    # Set the condition to update based on format test and Force parameter
    $shouldUpdate = (-not (Test-DirTagFormat -Content $content -IsDevContainer $isDevContainer)) -or $Force

    # Special handling for DevContainer DIR.TAG files when checking DevContainer
    if ($isDevContainer -and $CheckDevContainer) {
        $devContainerCount++
        if ($dockerModelRunnerAvailable -and (-not ($content -match "Docker Model Runner"))) {
            $shouldUpdate = $true
        }
    }

    if ($shouldUpdate) {
        Write-Host "Updating DIR.TAG file: $($file.FullName)" -ForegroundColor Yellow
        $updatedContent = Update-DirTagFormat -FilePath $file.FullName
        $updatedCount++

        # If DirTagManagement module is available, register the updated DIR.TAG
        if (Get-Command -Name "Update-DirTag" -ErrorAction SilentlyContinue) {
            try {
                Update-DirTag -Path $file.FullName -Force
                Write-Host "  Registered with DIR.TAG management system." -ForegroundColor Gray
            }
            catch {
                Write-Warning "  Could not register with DIR.TAG management system: $_"
            }
        }
    }
}

Write-Host "`nDIR.TAG cleanup complete. Updated $updatedCount files ($devContainerCount DevContainer files)." -ForegroundColor Green

if ($updatedCount -gt 0) {
    Write-Host "You may want to run Sync-DirTagProblems.ps1 to synchronize problem tracking with updated DIR.TAG files." -ForegroundColor Cyan
}

# DevContainer-specific summary
if ($CheckDevContainer) {
    if ($devContainerCount -gt 0) {
        Write-Host "`nDevContainer DIR.TAG Summary:" -ForegroundColor Cyan
        Write-Host "- $devContainerCount DevContainer DIR.TAG files processed"
        if ($dockerModelRunnerAvailable) {
            Write-Host "- Docker Model Runner integration information included in DevContainer DIR.TAG files" -ForegroundColor Green
        } else {
            Write-Host "- Docker Model Runner integration not available - please install Docker Desktop 4.40+ and enable Model Runner" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nNo DevContainer DIR.TAG files found." -ForegroundColor Yellow
    }
}