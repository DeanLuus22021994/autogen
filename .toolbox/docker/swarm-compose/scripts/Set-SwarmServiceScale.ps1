# Set-SwarmServiceScale.ps1
<#
.SYNOPSIS
    Scales a Docker Swarm service.

.DESCRIPTION
    This script scales a Docker Swarm service by setting the number of replicas.
    It provides options to gradually scale up or down and verify the deployment.
    Special handling is implemented for single replica deployments to ensure reliability.

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

.PARAMETER TestMode
    Optional. If specified, runs in test mode which simulates operations without making any actual changes.

.EXAMPLE
    .\Set-SwarmServiceScale.ps1 -StackName autogen -ServiceName inference -ReplicaCount 5

.EXAMPLE
    .\Set-SwarmServiceScale.ps1 -StackName ml-inference -ServiceName backend -ReplicaCount 10 -GradualScale -VerifyDeployment

.EXAMPLE
    .\Set-SwarmServiceScale.ps1 -StackName test-stack -ServiceName api -ReplicaCount 3 -TestMode

.EXAMPLE
    .\Set-SwarmServiceScale.ps1 -StackName autogen -ServiceName inference -ReplicaCount 1 -Verbose
    Scales a service to exactly one replica with detailed verbose logging for troubleshooting.
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
    [switch]$VerifyDeployment,

    [Parameter(Mandatory = $false)]
    [switch]$TestMode
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

    if ($TestMode) {
        Write-Host "[TEST MODE] Would execute: $currentCommand" -ForegroundColor Yellow
        # In test mode, return a simulated value based on service name to avoid hardcoding
        # This allows testing different replica scenarios in test mode
        $simulatedValue = if ($StackName -eq "test-1-replica") { 1 } else { 2 }
        Write-Host "[TEST MODE] Simulating current replicas: $simulatedValue" -ForegroundColor Yellow
        return $simulatedValue
    }

    try {
        $currentReplicas = Invoke-Expression $currentCommand

        if ($null -eq $currentReplicas -or $currentReplicas -eq "") {
            Write-Error "Service $ServiceFullName not found or is not in replicated mode"
            exit 1
        }

        # Ensure we're dealing with an integer
        $replicaCount = [int]$currentReplicas
        Write-Verbose "Detected $replicaCount current replicas for service $ServiceFullName"
        return $replicaCount
    }
    catch {
        Write-Error "Failed to get current replicas for service $ServiceFullName`: $_"
        exit 1
    }
}

function Test-Deployment {
    param (
        [string]$ServiceFullName,
        [int]$TargetReplicas,
        [int]$TimeoutSeconds = 300
    )

    Write-Host "Verifying deployment... (timeout: $TimeoutSeconds seconds)" -ForegroundColor Cyan
    $startTime = Get-Date
    $timeout = New-TimeSpan -Seconds $TimeoutSeconds

    while ((Get-Date) - $startTime -lt $timeout) {
        if ($TestMode) {
            # In test mode, simulate the verification process
            Write-Host "[TEST MODE] Would check deployment status for $ServiceFullName" -ForegroundColor Yellow
            Start-Sleep -Seconds 2  # Brief pause to simulate checking

            # Simulate successful response in test mode
            Write-Host "Deployment verified: $TargetReplicas/$TargetReplicas replicas are running (simulated)" -ForegroundColor Green
            return $true
        }

        # Two approaches for better reliability:
        # 1. First try with docker service ls which shows replica status
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
        }
        else {
            # 2. Fallback approach for when format might be different or for single replica services
            # Get actual replica count directly from inspect
            try {
                $inspectCommand = "docker service inspect $ServiceFullName --format `"{{.Spec.Mode.Replicated.Replicas}}`""
                $targetSpec = Invoke-Expression $inspectCommand

                if ($null -eq $targetSpec -or $targetSpec -eq "") {
                    Write-Host "Service not found or not in replicated mode. Retrying..." -ForegroundColor Yellow
                }
                else {
                    $inspectStatusCommand = "docker service inspect $ServiceFullName --format `"{{.Status.RunningTasks}}`""
                    $runningTasks = Invoke-Expression $inspectStatusCommand

                    if ($null -ne $runningTasks -and $runningTasks -ne "") {
                        $runningCount = [int]$runningTasks
                        $expectedCount = [int]$targetSpec

                        if ($runningCount -eq $expectedCount -and $expectedCount -eq $TargetReplicas) {
                            Write-Host "Deployment verified via inspect: $runningCount/$expectedCount replicas are running" -ForegroundColor Green
                            return $true
                        }

                        Write-Host "Deployment in progress (via inspect): $runningCount/$expectedCount replicas are running..." -ForegroundColor Yellow
                    }
                }
            }
            catch {
                Write-Host "Error checking service status: $_. Retrying..." -ForegroundColor Yellow
            }
        }

        Start-Sleep -Seconds 5
    }

    Write-Warning "Verification timed out after $TimeoutSeconds seconds"
    return $false
}

# Main script
try {
    if ($TestMode) {
        Write-Host "[TEST MODE] Running in test mode. No actual changes will be made." -ForegroundColor Yellow
    }

    $serviceFullName = Get-ServiceFullName -StackName $StackName -ServiceName $ServiceName
    $currentReplicas = Get-CurrentReplicas -ServiceFullName $serviceFullName

    Write-Host "Service: $serviceFullName" -ForegroundColor Cyan
    Write-Host "Current replicas: $currentReplicas" -ForegroundColor Cyan
    Write-Host "Target replicas: $ReplicaCount" -ForegroundColor Cyan

    if ($currentReplicas -eq $ReplicaCount) {
        Write-Host "Service already has $ReplicaCount replicas. No action needed." -ForegroundColor Green

        # Even if no scaling needed, verify deployment if requested
        if ($VerifyDeployment) {
            Write-Host "Verifying existing deployment..." -ForegroundColor Cyan
            $success = Test-Deployment -ServiceFullName $serviceFullName -TargetReplicas $ReplicaCount

            if (-not $success) {
                Write-Warning "Service verification failed. The service has $ReplicaCount replicas configured but they may not all be running."
                exit 1
            }
        }

        exit 0
    }

    # Special handling for scaling to 1 replica
    $isSingleReplicaTarget = $ReplicaCount -eq 1

    # Scale gradually if requested
    if ($GradualScale) {
        $isScalingUp = $ReplicaCount -gt $currentReplicas
        $step = if ($isScalingUp) { 1 } else { -1 }
        $stepDescription = if ($isScalingUp) { "up" } else { "down" }

        Write-Host "Gradually scaling $stepDescription..." -ForegroundColor Yellow

        for ($i = $currentReplicas + $step; ($isScalingUp -and $i -le $ReplicaCount) -or (-not $isScalingUp -and $i -ge $ReplicaCount); $i += $step) {
            Write-Host "Scaling to $i replicas..." -ForegroundColor Yellow

            # When scaling to exactly 1 replica, use a more reliable approach
            if ($i -eq 1) {
                Write-Verbose "Using direct scale command for single replica target"
                $scaleCommand = "docker service update --replicas=$i $serviceFullName"
            } else {
                $scaleCommand = "docker service scale $serviceFullName=$i"
            }

            if ($TestMode) {
                Write-Host "[TEST MODE] Would execute: $scaleCommand" -ForegroundColor Yellow
            }
            else {
                try {
                    $scaleOutput = Invoke-Expression $scaleCommand 2>&1
                    Write-Verbose "Scale output: $scaleOutput"

                    # Check for any error messages in the output
                    if ($scaleOutput -match "Error" -or $LASTEXITCODE -ne 0) {
                        Write-Warning "Potential issue during scaling: $scaleOutput"
                    }
                }
                catch {
                    Write-Error "Failed to scale service to $i replicas: $_"
                    exit 1
                }
            }

            if ($VerifyDeployment) {
                $verificationTimeout = 60  # shorter timeout for interim steps
                $success = Test-Deployment -ServiceFullName $serviceFullName -TargetReplicas $i -TimeoutSeconds $verificationTimeout

                if (-not $success) {
                    Write-Warning "Interim verification failed for $i replicas. Continuing anyway..."
                }
            }
            else {
                # Brief pause between scaling operations
                Start-Sleep -Seconds 5
            }
        }

        Write-Host "Gradual scaling complete" -ForegroundColor Green
    }
    else {
        # Scale directly to target
        Write-Host "Scaling to $ReplicaCount replicas..." -ForegroundColor Yellow

        # When scaling to exactly 1 replica, use a more reliable approach
        if ($isSingleReplicaTarget) {
            Write-Verbose "Using direct update command for single replica target"
            $scaleCommand = "docker service update --replicas=$ReplicaCount $serviceFullName"
        } else {
            $scaleCommand = "docker service scale $serviceFullName=$ReplicaCount"
        }

        if ($TestMode) {
            Write-Host "[TEST MODE] Would execute: $scaleCommand" -ForegroundColor Yellow
        }
        else {
            try {
                $scaleOutput = Invoke-Expression $scaleCommand 2>&1
                Write-Verbose "Scale output: $scaleOutput"

                # Check for any error messages in the output
                if ($scaleOutput -match "Error" -or $LASTEXITCODE -ne 0) {
                    Write-Warning "Potential issue during scaling: $scaleOutput"
                }
            }
            catch {
                Write-Error "Failed to scale service to $ReplicaCount replicas: $_"
                exit 1
            }
        }
    }

    # Verify final deployment if requested
    if ($VerifyDeployment) {
        $success = Test-Deployment -ServiceFullName $serviceFullName -TargetReplicas $ReplicaCount

        if (-not $success) {
            Write-Warning "Service may not have scaled correctly. Please check manually with 'docker service ls'"
            exit 1
        }
    }
    else {
        Write-Host "Scale command sent successfully" -ForegroundColor Green
        Write-Host "Run 'docker service ls' to verify the deployment" -ForegroundColor Cyan
    }
}
catch {
    Write-Error "Error scaling service: $_"
    exit 1
}
