# Backup-SwarmDeployment.ps1
<#
.SYNOPSIS
    Backs up a Docker Swarm deployment.

.DESCRIPTION
    This script creates backups of Docker Swarm deployments, including configuration, volumes, and stack definitions.
    It can be used to create point-in-time snapshots for disaster recovery.

.PARAMETER StackName
    The name of the stack to back up.

.PARAMETER BackupDir
    Optional. The directory where the backup will be stored. Default is the current directory.

.PARAMETER IncludeVolumes
    Optional. If specified, backs up Docker volume data.

.PARAMETER Compress
    Optional. If specified, compresses the backup into a single archive.

.EXAMPLE
    .\Backup-SwarmDeployment.ps1 -StackName autogen-inference

.EXAMPLE
    .\Backup-SwarmDeployment.ps1 -StackName autogen-db -BackupDir C:\Backups -IncludeVolumes -Compress
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [Parameter(Mandatory = $false)]
    [string]$BackupDir = (Get-Location),

    [Parameter(Mandatory = $false)]
    [switch]$IncludeVolumes,

    [Parameter(Mandatory = $false)]
    [switch]$Compress
)

function Get-Timestamp {
    return Get-Date -Format "yyyyMMdd-HHmmss"
}

function Backup-StackDefinition {
    param (
        [string]$Stack,
        [string]$OutputDir
    )

    # Create stack directory
    $stackDir = Join-Path $OutputDir "stack-definition"
    if (-not (Test-Path $stackDir)) {
        New-Item -Path $stackDir -ItemType Directory -Force | Out-Null
    }

    # Export stack definition
    $stackFile = Join-Path $stackDir "$Stack.yml"

    # Check if the stack exists
    $stackExists = $null -ne (docker stack ls --format "{{.Name}}" | Where-Object { $_ -eq $Stack })

    if (-not $stackExists) {
        Write-Warning "Stack '$Stack' does not exist. Cannot export stack definition."
        return
    }

    # Get services in the stack
    $services = docker stack services $Stack --format "{{.Name}}" | ForEach-Object { $_ -replace "^$Stack`_", "" }

    if ($services.Count -eq 0) {
        Write-Warning "No services found in stack '$Stack'."
        return
    }

    # Build stack definition based on running services
    $stackDefinition = @"
# Exported Stack: $Stack
# Generated: $(Get-Date)
version: '3.8'

services:
"@

    foreach ($service in $services) {
        $serviceDetails = docker service inspect "$Stack`_$service" | ConvertFrom-Json

        # Basic service definition
        $stackDefinition += @"

  $service:
    image: $($serviceDetails.Spec.TaskTemplate.ContainerSpec.Image)
"@

        # Add deployment configuration
        if ($serviceDetails.Spec.Mode.Replicated) {
            $stackDefinition += @"

    deploy:
      replicas: $($serviceDetails.Spec.Mode.Replicated.Replicas)
"@
        } elseif ($serviceDetails.Spec.Mode.Global) {
            $stackDefinition += @"

    deploy:
      mode: global
"@
        }

        # Add environment variables
        if ($serviceDetails.Spec.TaskTemplate.ContainerSpec.Env) {
            $stackDefinition += @"

    environment:
"@
            foreach ($env in $serviceDetails.Spec.TaskTemplate.ContainerSpec.Env) {
                $stackDefinition += @"

      - $env
"@
            }
        }

        # Add ports
        if ($serviceDetails.Spec.EndpointSpec.Ports) {
            $stackDefinition += @"

    ports:
"@
            foreach ($port in $serviceDetails.Spec.EndpointSpec.Ports) {
                $stackDefinition += @"

      - "$($port.PublishedPort):$($port.TargetPort)"
"@
            }
        }
    }

    # Add networks
    $networks = docker network ls --filter "label=com.docker.stack.namespace=$Stack" --format "{{.Name}}" | ForEach-Object { $_ -replace "^$Stack`_", "" }

    if ($networks.Count -gt 0) {
        $stackDefinition += @"

networks:
"@
        foreach ($network in $networks) {
            $networkDetails = docker network inspect "$Stack`_$network" | ConvertFrom-Json

            $stackDefinition += @"

  $network:
    driver: $($networkDetails.Driver)
"@

            if ($networkDetails.Attachable) {
                $stackDefinition += @"

    attachable: true
"@
            }
        }
    }

    # Add volumes
    $volumes = docker volume ls --filter "label=com.docker.stack.namespace=$Stack" --format "{{.Name}}" | ForEach-Object { $_ -replace "^$Stack`_", "" }

    if ($volumes.Count -gt 0) {
        $stackDefinition += @"

volumes:
"@
        foreach ($volume in $volumes) {
            $stackDefinition += @"

  $volume:
    driver: local
"@
        }
    }

    # Write stack definition to file
    $stackDefinition | Out-File -FilePath $stackFile -Encoding utf8 -Force

    Write-Host "Stack definition for '$Stack' exported to $stackFile" -ForegroundColor Green
    return $stackFile
}

function Backup-ServiceConfigs {
    param (
        [string]$Stack,
        [string]$OutputDir
    )

    # Create configs directory
    $configsDir = Join-Path $OutputDir "configs"
    if (-not (Test-Path $configsDir)) {
        New-Item -Path $configsDir -ItemType Directory -Force | Out-Null
    }

    # Get services in the stack
    $services = docker stack services $Stack --format "{{.Name}}"

    if ($services.Count -eq 0) {
        Write-Warning "No services found in stack '$Stack'."
        return
    }

    foreach ($service in $services) {
        $serviceJson = Join-Path $configsDir "$service.json"
        docker service inspect $service | Out-File -FilePath $serviceJson -Encoding utf8 -Force
    }

    Write-Host "Service configs for '$Stack' exported to $configsDir" -ForegroundColor Green
}

function Backup-Volumes {
    param (
        [string]$Stack,
        [string]$OutputDir
    )

    # Create volumes directory
    $volumesDir = Join-Path $OutputDir "volumes"
    if (-not (Test-Path $volumesDir)) {
        New-Item -Path $volumesDir -ItemType Directory -Force | Out-Null
    }

    # Get volumes in the stack
    $volumes = docker volume ls --filter "label=com.docker.stack.namespace=$Stack" --format "{{.Name}}"

    if ($volumes.Count -eq 0) {
        Write-Warning "No volumes found in stack '$Stack'."
        return
    }

    foreach ($volume in $volumes) {
        $volumeDir = Join-Path $volumesDir $volume
        if (-not (Test-Path $volumeDir)) {
            New-Item -Path $volumeDir -ItemType Directory -Force | Out-Null
        }

        # Create a temporary container to access the volume
        $containerId = docker run -d --rm -v "$($volume):/backup-src" alpine:latest sleep 600

        # Copy contents from volume to backup directory
        docker exec $containerId sh -c "tar -cf - -C /backup-src . | gzip -9" | tar -xzf - -C $volumeDir

        # Remove the temporary container
        docker stop $containerId | Out-Null

        Write-Host "Volume '$volume' backed up to $volumeDir" -ForegroundColor Green
    }
}

function Compress-Backup {
    param (
        [string]$BackupPath
    )

    $parentDir = Split-Path -Parent $BackupPath
    $dirName = Split-Path -Leaf $BackupPath
    $zipPath = Join-Path $parentDir "$dirName.zip"

    Write-Host "Compressing backup to $zipPath..." -ForegroundColor Cyan

    # Compress directory
    if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
        Compress-Archive -Path "$BackupPath\*" -DestinationPath $zipPath -Force
    } else {
        # Alternative compression method if Compress-Archive is not available
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($BackupPath, $zipPath)
    }

    Write-Host "Backup compressed to $zipPath" -ForegroundColor Green
    return $zipPath
}

# Main script
try {
    # Validate and create backup directory
    if (-not (Test-Path $BackupDir)) {
        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Timestamp
    $backupPath = Join-Path $BackupDir "$StackName-backup-$timestamp"

    if (-not (Test-Path $backupPath)) {
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    }

    Write-Host "Starting backup of stack '$StackName' to $backupPath" -ForegroundColor Cyan

    # Backup stack definition
    Backup-StackDefinition -Stack $StackName -OutputDir $backupPath

    # Backup service configs
    Backup-ServiceConfigs -Stack $StackName -OutputDir $backupPath

    # Backup volumes if requested
    if ($IncludeVolumes) {
        Write-Host "Backing up volumes for stack '$StackName'..." -ForegroundColor Cyan
        Backup-Volumes -Stack $StackName -OutputDir $backupPath
    }

    # Compress backup if requested
    if ($Compress) {
        $zipPath = Compress-Backup -BackupPath $backupPath

        # Remove uncompressed files if compression was successful
        if (Test-Path $zipPath) {
            Remove-Item -Path $backupPath -Recurse -Force
            Write-Host "Uncompressed backup files removed" -ForegroundColor Gray
        }
    }

    Write-Host "Backup completed successfully" -ForegroundColor Green
} catch {
    Write-Error "Error backing up Swarm deployment: $_"
    exit 1
}
