# Remove-SwarmStack.ps1
<#
.SYNOPSIS
    Removes a Docker Swarm stack.

.DESCRIPTION
    This script removes a Docker Swarm stack and optionally removes associated networks and volumes.

.PARAMETER StackName
    The name of the stack to remove.

.PARAMETER RemoveNetworks
    Optional. If specified, removes networks associated with the stack.

.PARAMETER RemoveVolumes
    Optional. If specified, removes volumes associated with the stack.

.EXAMPLE
    .\Remove-SwarmStack.ps1 -StackName autogen

.EXAMPLE
    .\Remove-SwarmStack.ps1 -StackName ml-inference -RemoveNetworks -RemoveVolumes
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [Parameter(Mandatory = $false)]
    [switch]$RemoveNetworks,

    [Parameter(Mandatory = $false)]
    [switch]$RemoveVolumes
)

try {
    # Check if stack exists
    $stackExists = $null -ne (docker stack ls --format "{{.Name}}" | Where-Object { $_ -eq $StackName })

    if (-not $stackExists) {
        Write-Warning "Stack '$StackName' does not exist"
        exit 0
    }

    # List services before removal
    Write-Host "Services in stack '$StackName' to be removed:" -ForegroundColor Yellow
    docker service ls --filter "name=$StackName"

    # Remove the stack
    Write-Host "Removing stack '$StackName'..." -ForegroundColor Cyan
    docker stack rm $StackName

    # Wait for stack removal to complete
    $attempts = 0
    $maxAttempts = 30
    do {
        Start-Sleep -Seconds 2
        $stackExists = $null -ne (docker stack ls --format "{{.Name}}" | Where-Object { $_ -eq $StackName })
        $attempts++

        if ($stackExists) {
            Write-Host "Waiting for stack removal to complete... ($attempts/$maxAttempts)" -ForegroundColor Gray
        }
    } until ((-not $stackExists) -or ($attempts -ge $maxAttempts))

    if ($stackExists) {
        Write-Warning "Stack removal is taking longer than expected. Please check manually with 'docker stack ls'"
    } else {
        Write-Host "Stack '$StackName' removed successfully" -ForegroundColor Green
    }

    # Remove networks if requested
    if ($RemoveNetworks) {
        Write-Host "Checking for networks associated with stack '$StackName'..." -ForegroundColor Cyan
        $networks = docker network ls --filter "name=$StackName" --format "{{.Name}}"

        foreach ($network in $networks) {
            Write-Host "Removing network: $network" -ForegroundColor Yellow
            docker network rm $network
        }
    }

    # Remove volumes if requested
    if ($RemoveVolumes) {
        Write-Host "Checking for volumes associated with stack '$StackName'..." -ForegroundColor Cyan
        $volumes = docker volume ls --filter "name=$StackName" --format "{{.Name}}"

        foreach ($volume in $volumes) {
            Write-Host "Removing volume: $volume" -ForegroundColor Yellow
            docker volume rm $volume
        }
    }

    Write-Host "Stack cleanup completed" -ForegroundColor Green
} catch {
    Write-Error "Error removing stack: $_"
    exit 1
}
