# Watch-SwarmServices.ps1
<#
.SYNOPSIS
    Monitors Docker Swarm services in real-time.

.DESCRIPTION
    This script provides real-time monitoring of Docker Swarm services,
    showing detailed information about service status, replicas, and resources.

.PARAMETER StackName
    Optional. The name of the stack to monitor. If not specified, all services are monitored.

.PARAMETER RefreshInterval
    Optional. The refresh interval in seconds. Default is 5 seconds.

.PARAMETER ShowLogs
    Optional. If specified, shows the logs for services in addition to status.

.EXAMPLE
    .\Watch-SwarmServices.ps1

.EXAMPLE
    .\Watch-SwarmServices.ps1 -StackName ml-inference -RefreshInterval 10 -ShowLogs
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$StackName,

    [Parameter(Mandatory = $false)]
    [int]$RefreshInterval = 5,

    [Parameter(Mandatory = $false)]
    [switch]$ShowLogs
)

function Format-ColorStatus {
    param (
        [string]$Status
    )

    switch -Regex ($Status) {
        "Running|Complete" {
            Write-Host $Status -ForegroundColor Green -NoNewline
        }
        "Starting|Preparing" {
            Write-Host $Status -ForegroundColor Yellow -NoNewline
        }
        "Failed|Error|Rejected" {
            Write-Host $Status -ForegroundColor Red -NoNewline
        }
        default {
            Write-Host $Status -NoNewline
        }
    }
}

function Get-ServiceDetails {
    param (
        [string]$StackFilter
    )

    $filter = ""
    if ($StackFilter) {
        $filter = "--filter `"name=$StackFilter`""
    }

    $servicesCommand = "docker service ls $filter --format `"{{.Name}}|{{.Replicas}}|{{.Image}}|{{.Ports}}`""
    $services = Invoke-Expression $servicesCommand

    $results = @()
    foreach ($service in $services) {
        $parts = $service -split '\|'
        if ($parts.Count -ge 3) {
            $name = $parts[0]
            $replicas = $parts[1]
            $image = $parts[2]
            $ports = if ($parts.Count -gt 3) { $parts[3] } else { "" }

            # Get detailed service information
            $inspectCommand = "docker service inspect $name --format `"{{json .}}`""
            $serviceDetails = Invoke-Expression $inspectCommand | ConvertFrom-Json

            # Extract useful information
            $createdAt = $serviceDetails.CreatedAt
            $updateStatus = if ($serviceDetails.UpdateStatus) { $serviceDetails.UpdateStatus.State } else { "n/a" }

            # Get tasks for the service
            $tasksCommand = "docker service ps $name --format `"{{.Name}}|{{.Node}}|{{.CurrentState}}|{{.Error}}`" --no-trunc"
            $tasks = Invoke-Expression $tasksCommand

            $taskDetails = @()
            foreach ($task in $tasks) {
                $taskParts = $task -split '\|'
                if ($taskParts.Count -ge 3) {
                    $taskName = $taskParts[0]
                    $node = $taskParts[1]
                    $state = $taskParts[2]
                    $error = if ($taskParts.Count -gt 3) { $taskParts[3] } else { "" }

                    $taskDetails += [PSCustomObject]@{
                        Name = $taskName
                        Node = $node
                        State = $state
                        Error = $error
                    }
                }
            }

            $results += [PSCustomObject]@{
                Name = $name
                Replicas = $replicas
                Image = $image
                Ports = $ports
                CreatedAt = $createdAt
                UpdateStatus = $updateStatus
                Tasks = $taskDetails
            }
        }
    }

    return $results
}

# Main monitoring loop
try {
    Write-Host "Starting Swarm service monitoring" -ForegroundColor Cyan
    if ($StackName) {
        Write-Host "Monitoring stack: $StackName" -ForegroundColor Cyan
    } else {
        Write-Host "Monitoring all services" -ForegroundColor Cyan
    }
    Write-Host "Refresh interval: $RefreshInterval seconds" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to exit" -ForegroundColor Cyan
    Write-Host ""

    while ($true) {
        Clear-Host
        $services = Get-ServiceDetails -StackFilter $StackName

        Write-Host "DOCKER SWARM SERVICES MONITOR" -ForegroundColor Cyan
        Write-Host "==============================" -ForegroundColor Cyan
        Write-Host "Time: $(Get-Date)" -ForegroundColor Gray
        Write-Host ""

        if ($services.Count -eq 0) {
            Write-Host "No services found" -ForegroundColor Yellow
        } else {
            foreach ($service in $services) {
                Write-Host "Service: " -NoNewline
                Write-Host $service.Name -ForegroundColor Green
                Write-Host "  Image:    $($service.Image)"
                Write-Host "  Replicas: $($service.Replicas)"
                if ($service.Ports) {
                    Write-Host "  Ports:    $($service.Ports)"
                }
                Write-Host "  Created:  $($service.CreatedAt)"
                Write-Host "  Update:   " -NoNewline

                switch -Regex ($service.UpdateStatus) {
                    "completed" { Write-Host $service.UpdateStatus -ForegroundColor Green }
                    "updating|paused" { Write-Host $service.UpdateStatus -ForegroundColor Yellow }
                    "rollback" { Write-Host $service.UpdateStatus -ForegroundColor Red }
                    default { Write-Host $service.UpdateStatus }
                }

                Write-Host "  Tasks:"
                foreach ($task in $service.Tasks) {
                    Write-Host "    - $($task.Name) on $($task.Node) - " -NoNewline
                    Format-ColorStatus -Status $task.State
                    if ($task.Error) {
                        Write-Host " - ERROR: $($task.Error)" -ForegroundColor Red
                    } else {
                        Write-Host ""
                    }
                }

                # Show logs if requested
                if ($ShowLogs) {
                    Write-Host "  Logs (last 5 entries):"
                    $logsCommand = "docker service logs --tail 5 $($service.Name)"
                    $logs = Invoke-Expression $logsCommand
                    foreach ($logEntry in $logs) {
                        Write-Host "    $logEntry" -ForegroundColor Gray
                    }
                }

                Write-Host ""
            }
        }

        Write-Host "Refreshing in $RefreshInterval seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds $RefreshInterval
    }
} catch {
    if ($_.Exception.Message -notmatch "User canceled operation") {
        Write-Error "Error monitoring services: $_"
        exit 1
    }
}
