# Restore-SwarmDeployment.ps1
<#
.SYNOPSIS
    Restores a Docker Swarm deployment from backup.

.DESCRIPTION
    This script restores Docker Swarm deployments from backups created with Backup-SwarmDeployment.ps1.
    It can restore stack configurations, volumes, and redeploy stacks.

.PARAMETER BackupPath
    The path to the backup directory or zip file.

.PARAMETER StackName
    Optional. The name of the stack to restore. If not specified, uses the original stack name.

.PARAMETER RestoreVolumes
    Optional. If specified, restores Docker volume data.

.PARAMETER SkipDeploy
    Optional. If specified, prepares the restoration but does not deploy the stack.

.EXAMPLE
    .\Restore-SwarmDeployment.ps1 -BackupPath C:\Backups\autogen-inference-backup-20250501-120000

.EXAMPLE
    .\Restore-SwarmDeployment.ps1 -BackupPath C:\Backups\autogen-db-backup-20250501-120000.zip -StackName autogen-db-restored -RestoreVolumes
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,

    [Parameter(Mandatory = $false)]
    [string]$StackName,

    [Parameter(Mandatory = $false)]
    [switch]$RestoreVolumes,

    [Parameter(Mandatory = $false)]
    [switch]$SkipDeploy
)

function Extract-Backup {
    param (
        [string]$ZipPath,
        [string]$ExtractPath
    )

    Write-Host "Extracting backup from $ZipPath..." -ForegroundColor Cyan

    # Extract archive
    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
    } else {
        # Alternative extraction method if Expand-Archive is not available
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractPath)
    }

    Write-Host "Backup extracted to $ExtractPath" -ForegroundColor Green
    return $ExtractPath
}

function Get-OriginalStackName {
    param (
        [string]$BackupDir
    )

    $stackDefinitionDir = Join-Path $BackupDir "stack-definition"
    if (-not (Test-Path $stackDefinitionDir)) {
        Write-Error "Invalid backup directory: Stack definition not found"
        exit 1
    }

    $stackFiles = Get-ChildItem -Path $stackDefinitionDir -Filter "*.yml"

    if ($stackFiles.Count -eq 0) {
        Write-Error "No stack definition files found in the backup"
        exit 1
    }

    # Get the first stack file name without extension
    $originalStackName = [System.IO.Path]::GetFileNameWithoutExtension($stackFiles[0].Name)

    return $originalStackName
}

function Restore-Volumes {
    param (
        [string]$BackupDir,
        [string]$TargetStack
    )

    $volumesDir = Join-Path $BackupDir "volumes"
    if (-not (Test-Path $volumesDir)) {
        Write-Warning "Volumes directory not found in backup"
        return
    }

    $volumeDirs = Get-ChildItem -Path $volumesDir -Directory

    if ($volumeDirs.Count -eq 0) {
        Write-Warning "No volume backups found"
        return
    }

    foreach ($volumeDir in $volumeDirs) {
        $volumeName = $volumeDir.Name
        $targetVolumeName = $volumeName

        # If restoring to a different stack name, update volume name
        if ($volumeName -match "^(.+)_(.+)$" -and $Matches[1] -ne $TargetStack) {
            $targetVolumeName = "${TargetStack}_$($Matches[2])"
        }

        # Check if volume exists
        $volumeExists = $null -ne (docker volume ls --format "{{.Name}}" | Where-Object { $_ -eq $targetVolumeName })

        if (-not $volumeExists) {
            Write-Host "Creating volume '$targetVolumeName'..." -ForegroundColor Yellow
            docker volume create $targetVolumeName | Out-Null
        }

        # Create a temporary container to access the volume
        $containerId = docker run -d --rm -v "$($targetVolumeName):/backup-dest" -v "$($volumeDir.FullName):/backup-src" alpine:latest sleep 600

        # Copy contents from backup to volume
        docker exec $containerId sh -c "rm -rf /backup-dest/* && cp -a /backup-src/. /backup-dest/"

        # Remove the temporary container
        docker stop $containerId | Out-Null

        Write-Host "Volume '$volumeName' restored to '$targetVolumeName'" -ForegroundColor Green
    }
}

function Deploy-Stack {
    param (
        [string]$StackDefinitionPath,
        [string]$TargetStack
    )

    if (-not (Test-Path $StackDefinitionPath)) {
        Write-Error "Stack definition file not found: $StackDefinitionPath"
        exit 1
    }

    # Deploy the stack
    Write-Host "Deploying stack '$TargetStack'..." -ForegroundColor Cyan
    docker stack deploy --compose-file $StackDefinitionPath $TargetStack

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Stack '$TargetStack' deployed successfully" -ForegroundColor Green

        # Display services
        Write-Host "Services in stack '$TargetStack':" -ForegroundColor Cyan
        docker service ls --filter "name=$TargetStack"
    } else {
        Write-Error "Failed to deploy stack '$TargetStack'"
        exit 1
    }
}

# Main script
try {
    # Check if the backup path is a directory or zip file
    $workingDir = $BackupPath
    $isZipBackup = $BackupPath.EndsWith(".zip") -and (Test-Path $BackupPath -PathType Leaf)

    if ($isZipBackup) {
        $extractPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
        $workingDir = Extract-Backup -ZipPath $BackupPath -ExtractPath $extractPath
    } elseif (-not (Test-Path $BackupPath -PathType Container)) {
        Write-Error "Backup path does not exist or is not a directory/zip file: $BackupPath"
        exit 1
    }

    # Get original stack name from backup
    $originalStackName = Get-OriginalStackName -BackupDir $workingDir

    # Use provided stack name or original stack name
    $targetStackName = if ($StackName) { $StackName } else { $originalStackName }

    Write-Host "Restoring stack '$originalStackName' as '$targetStackName'" -ForegroundColor Cyan

    # Restore volumes if requested
    if ($RestoreVolumes) {
        Write-Host "Restoring volumes..." -ForegroundColor Cyan
        Restore-Volumes -BackupDir $workingDir -TargetStack $targetStackName
    }

    # Deploy stack if not skipped
    if (-not $SkipDeploy) {
        $stackDefinitionPath = Join-Path $workingDir "stack-definition\$originalStackName.yml"
        Deploy-Stack -StackDefinitionPath $stackDefinitionPath -TargetStack $targetStackName
    } else {
        Write-Host "Stack deployment skipped" -ForegroundColor Yellow
        Write-Host "To deploy the stack manually, run:" -ForegroundColor Yellow
        Write-Host "docker stack deploy --compose-file `"$workingDir\stack-definition\$originalStackName.yml`" $targetStackName" -ForegroundColor White
    }

    # Clean up extracted files if backup was a zip
    if ($isZipBackup -and (Test-Path $extractPath)) {
        Remove-Item -Path $extractPath -Recurse -Force
        Write-Host "Temporary extraction directory removed" -ForegroundColor Gray
    }

    Write-Host "Restore completed successfully" -ForegroundColor Green
} catch {
    Write-Error "Error restoring Swarm deployment: $_"
    exit 1
}
