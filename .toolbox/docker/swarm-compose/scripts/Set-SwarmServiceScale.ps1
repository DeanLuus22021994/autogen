# Set-SwarmServiceScale.ps1
<#
.SYNOPSIS
    Scales a Docker Swarm service.

.DESCRIPTION
    This script scales a Docker Swarm service by setting the number of replicas.
    It provides options to gradually scale up or down and verify the deployment.

.PARAMETER StackName
    The name of the stack containing the service.

.PARAMETER ServiceName
    The name of the service to scale. This can be the service name with or without the stack name prefix.
    If the stack name is provided, the full service name will be constructed as <stack-name>_<service-name>.

.PARAMETER ReplicaCount
    The number of replicas to scale to.

.PARAMETER GradualScale
    Optional. If specified, scales the service gradually in small increments to avoid overwhelming the system.

.PARAMETER VerifyDeployment
    Optional. If specified, verifies that the service has been successfully scaled before exiting.

.EXAMPLE
    .\Set-SwarmServiceScale.ps1 -StackName autogen -ServiceName inference -ReplicaCount 5

.EXAMPLE
    .\Set-SwarmServiceScale.ps1 -StackName ml-inference -ServiceName backend -ReplicaCount 10 -GradualScale -VerifyDeployment
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [Parameter(Mandatory = $true)]
    [string]$ServiceName,

    [Parameter(Mandatory = $true)]
    [int]$ReplicaCount,

    [Parameter(Mandatory = $false)]
    [switch]$GradualScale,

    [Parameter(Mandatory = $false)]
    [switch]$VerifyDeployment
)

function Get-ServiceFullName {
    param (
        [string]$StackName,
        [string]$ServiceName
    )

    # Check if service name already includes stack name
    if ($ServiceName.StartsWith("$StackName`_")) {
        return $ServiceName
    }

    return "$StackName`_$ServiceName"
}

function Get-CurrentReplicas {
    param (
        [string]$ServiceFullName
    )

    $currentCommand = "docker service inspect $ServiceFullName --format `"{{.Spec.Mode.Replicated.Replicas}}`""
    $currentReplicas = Invoke-Expression $currentCommand

    if ($null -eq $currentReplicas -or $currentReplicas -eq "") {
        Write-Error "Service $ServiceFullName not found or is not in replicated mode"
        exit 1
    }

    return [int]$currentReplicas
}

function Verify-Deployment {
    param (
        [string]$ServiceFullName,
        [int]$TargetReplicas,
        [int]$TimeoutSeconds = 300
    )

    Write-Host "Verifying deployment... (timeout: $TimeoutSeconds seconds)" -ForegroundColor Cyan
    $startTime = Get-Date
    $timeout = New-TimeSpan -Seconds $TimeoutSeconds

    while ((Get-Date) - $startTime -lt $timeout) {
        $statusCommand = "docker service ls --filter `"name=$ServiceFullName`" --format `"{{.Name}} {{.Replicas}}`""
        $status = Invoke-Expression $statusCommand

        if ($status -match "$ServiceFullName\s+(\d+)/(\d+)") {
            $current = [int]$Matches[1]
            $expected = [int]$Matches[2]

            if ($current -eq $expected -and $expected -eq $TargetReplicas) {
                Write-Host "Deployment verified: $current/$expected replicas are running" -ForegroundColor Green
                return $true
            }

            Write-Host "Deployment in progress: $current/$expected replicas are running..." -ForegroundColor Yellow
        } else {
            Write-Host "Could not determine service status. Retrying..." -ForegroundColor Yellow
        }

        Start-Sleep -Seconds 5
    }

    Write-Warning "Verification timed out after $TimeoutSeconds seconds"
    return $false
}

# Main script
try {
    $serviceFullName = Get-ServiceFullName -StackName $StackName -ServiceName $ServiceName
    $currentReplicas = Get-CurrentReplicas -ServiceFullName $serviceFullName

    Write-Host "Service: $serviceFullName" -ForegroundColor Cyan
    Write-Host "Current replicas: $currentReplicas" -ForegroundColor Cyan
    Write-Host "Target replicas: $ReplicaCount" -ForegroundColor Cyan

    if ($currentReplicas -eq $ReplicaCount) {
        Write-Host "Service already has $ReplicaCount replicas. No action needed." -ForegroundColor Green
        exit 0
    }

    # Scale gradually if requested
    if ($GradualScale) {
        $isScalingUp = $ReplicaCount -gt $currentReplicas
        $step = if ($isScalingUp) { 1 } else { -1 }
        $stepDescription = if ($isScalingUp) { "up" } else { "down" }

        Write-Host "Gradually scaling $stepDescription..." -ForegroundColor Yellow

        for ($i = $currentReplicas + $step; $isScalingUp ? ($i -le $ReplicaCount) : ($i -ge $ReplicaCount); $i += $step) {
            Write-Host "Scaling to $i replicas..." -ForegroundColor Yellow
            $scaleCommand = "docker service scale $serviceFullName=$i"
            Invoke-Expression $scaleCommand | Out-Null

            if ($VerifyDeployment) {
                $verificationTimeout = 60  # shorter timeout for interim steps
                Verify-Deployment -ServiceFullName $serviceFullName -TargetReplicas $i -TimeoutSeconds $verificationTimeout | Out-Null
            } else {
                # Brief pause between scaling operations
                Start-Sleep -Seconds 5
            }
        }

        Write-Host "Gradual scaling complete" -ForegroundColor Green
    } else {
        # Scale directly to target
        Write-Host "Scaling to $ReplicaCount replicas..." -ForegroundColor Yellow
        $scaleCommand = "docker service scale $serviceFullName=$ReplicaCount"
        Invoke-Expression $scaleCommand | Out-Null
    }

    # Verify final deployment if requested
    if ($VerifyDeployment) {
        $success = Verify-Deployment -ServiceFullName $serviceFullName -TargetReplicas $ReplicaCount

        if (-not $success) {
            Write-Warning "Service may not have scaled correctly. Please check manually with 'docker service ls'"
            exit 1
        }
    } else {
        Write-Host "Scale command sent successfully" -ForegroundColor Green
        Write-Host "Run 'docker service ls' to verify the deployment" -ForegroundColor Cyan
    }

} catch {
    Write-Error "Error scaling service: $_"
    exit 1
}
