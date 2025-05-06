# Diagnose-SwarmCluster.ps1
<#
.SYNOPSIS
    Diagnoses issues with a Docker Swarm cluster.

.DESCRIPTION
    This script performs comprehensive diagnostics on a Docker Swarm cluster,
    checking node health, network connectivity, service states, and resource usage.

.PARAMETER OutputFile
    Optional. Path to save the diagnostic report. If not specified, output is displayed on screen only.

.PARAMETER IncludeServiceLogs
    Optional. If specified, includes recent service logs in the diagnostic report.

.PARAMETER DetailedReport
    Optional. If specified, generates a more detailed report with additional diagnostics.

.EXAMPLE
    .\Diagnose-SwarmCluster.ps1

.EXAMPLE
    .\Diagnose-SwarmCluster.ps1 -OutputFile C:\diagnostics\swarm-report.txt -IncludeServiceLogs -DetailedReport
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$OutputFile,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeServiceLogs,

    [Parameter(Mandatory = $false)]
    [switch]$DetailedReport
)

function Write-SectionHeader {
    param ([string]$Title)

    $header = "`n========== $Title ==========`n"
    Write-Host $header -ForegroundColor Cyan
    return $header
}

function Check-DockerDaemon {
    $header = Write-SectionHeader "Docker Daemon Status"
    $output = ""

    try {
        $info = docker info --format "{{json .}}" | ConvertFrom-Json
        $output += "Docker Version: $($info.ServerVersion)`n"
        $output += "OS/Arch: $($info.OperatingSystem)/$($info.Architecture)`n"
        $output += "Kernel Version: $($info.KernelVersion)`n"
        $output += "CPUs: $($info.NCPU)`n"
        $output += "Total Memory: $($info.MemTotal)`n"

        # Check Docker storage driver
        $output += "Storage Driver: $($info.Driver)`n"

        # Check Docker registry configuration
        if ($info.RegistryConfig.InsecureRegistryCIDRs) {
            $output += "Insecure Registries: $($info.RegistryConfig.InsecureRegistryCIDRs -join ', ')`n"
        }

        Write-Host $output
    } catch {
        $errorMsg = "ERROR: Could not connect to Docker daemon. $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        $output += "$errorMsg`n"
    }

    return $header + $output
}

function Check-SwarmStatus {
    $header = Write-SectionHeader "Swarm Cluster Status"
    $output = ""

    try {
        $swarmInfo = docker info --format "{{json .Swarm}}" | ConvertFrom-Json

        if ($swarmInfo.LocalNodeState -ne "active") {
            $output += "Swarm is not active. Current state: $($swarmInfo.LocalNodeState)`n"
            $output += "Use 'docker swarm init' or 'docker swarm join' to activate Swarm mode.`n"
        } else {
            $output += "Swarm Mode: Active`n"
            $output += "Node ID: $($swarmInfo.NodeID)`n"
            $output += "Cluster ID: $($swarmInfo.Cluster.ID)`n"
            $output += "Managers: $($swarmInfo.Managers)`n"
            $output += "Nodes: $($swarmInfo.Nodes)`n"

            # Check if cluster is healthy
            if ($swarmInfo.Error) {
                $output += "Cluster Error: $($swarmInfo.Error)`n"
            } else {
                $output += "Cluster Status: Healthy`n"
            }
        }

        Write-Host $output
    } catch {
        $errorMsg = "ERROR: Could not retrieve Swarm status. $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        $output += "$errorMsg`n"
    }

    return $header + $output
}

function Check-Nodes {
    $header = Write-SectionHeader "Node Status"
    $output = ""

    try {
        $nodes = docker node ls --format "{{.ID}}" 2>$null

        if ($nodes.Count -eq 0) {
            $output += "No nodes found in the Swarm cluster.`n"
        } else {
            $output += "Node List:`n"
            $nodeDetails = docker node ls
            $output += "$nodeDetails`n`n"

            foreach ($nodeId in $nodes) {
                $nodeInfo = docker node inspect $nodeId --format "{{json .}}" | ConvertFrom-Json

                $output += "Node: $($nodeInfo.Description.Hostname) (ID: $($nodeId.Substring(0, 12)))`n"
                $output += "  Role: $($nodeInfo.Spec.Role)`n"
                $output += "  Availability: $($nodeInfo.Spec.Availability)`n"
                $output += "  Status: $($nodeInfo.Status.State)"

                # Check if node is down
                if ($nodeInfo.Status.State -ne "ready") {
                    $output += " - WARNING: Node is not in ready state!`n"
                } else {
                    $output += " - OK`n"
                }

                # Check node address reachability
                $output += "  Address: $($nodeInfo.Status.Addr)`n"

                # Add detailed resource info if requested
                if ($DetailedReport) {
                    # Try to get node resource usage if possible
                    if ($nodeInfo.Description.Platform.OS -eq "linux") {
                        try {
                            $diskUsage = docker run --rm --privileged --net=host -v /:/host alpine df -h /host
                            $output += "  Disk Usage: $($diskUsage | Select-Object -Skip 1 | Select-Object -First 1)`n"

                            $memInfo = docker run --rm --privileged --net=host alpine free -h
                            $output += "  Memory Usage: $($memInfo | Select-Object -Skip 1 | Select-Object -First 1)`n"
                        } catch {
                            $output += "  Could not retrieve resource usage.`n"
                        }
                    }
                }

                $output += "`n"
            }
        }

        Write-Host $output
    } catch {
        $errorMsg = "ERROR: Could not retrieve node information. $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        $output += "$errorMsg`n"
    }

    return $header + $output
}

function Check-Services {
    $header = Write-SectionHeader "Service Status"
    $output = ""

    try {
        $services = docker service ls --format "{{.ID}}" 2>$null

        if ($services.Count -eq 0) {
            $output += "No services found in the Swarm cluster.`n"
        } else {
            $output += "Service List:`n"
            $serviceList = docker service ls
            $output += "$serviceList`n`n"

            foreach ($serviceId in $services) {
                $serviceInfo = docker service inspect $serviceId --format "{{json .}}" | ConvertFrom-Json
                $serviceName = $serviceInfo.Spec.Name

                $output += "Service: $serviceName (ID: $($serviceId.Substring(0, 12)))`n"
                $output += "  Image: $($serviceInfo.Spec.TaskTemplate.ContainerSpec.Image)`n"

                # Check service mode
                if ($serviceInfo.Spec.Mode.Replicated) {
                    $desiredReplicas = $serviceInfo.Spec.Mode.Replicated.Replicas
                    $output += "  Mode: Replicated (Desired: $desiredReplicas)`n"
                } elseif ($serviceInfo.Spec.Mode.Global) {
                    $output += "  Mode: Global`n"
                }

                # Check service tasks
                $tasks = docker service ps $serviceName --format "{{.CurrentState}}"
                $runningTasks = ($tasks | Where-Object { $_ -match "Running" }).Count
                $totalTasks = $tasks.Count

                $output += "  Tasks: $runningTasks running out of $totalTasks total`n"

                # Check failed tasks
                $failedTasks = $tasks | Where-Object { $_ -match "Failed|Rejected|Shutdown" }
                if ($failedTasks.Count -gt 0) {
                    $output += "  WARNING: $($failedTasks.Count) tasks are in a failed state!`n"

                    # Get failed task details
                    $output += "  Failed Tasks:`n"
                    $taskDetails = docker service ps --filter "desired-state=shutdown" $serviceName
                    $output += "$taskDetails`n"
                }

                # Include logs if requested
                if ($IncludeServiceLogs) {
                    $output += "  Recent Logs:`n"
                    try {
                        $logs = docker service logs --tail 10 $serviceName 2>&1
                        foreach ($line in $logs) {
                            $output += "    $line`n"
                        }
                    } catch {
                        $output += "    Could not retrieve logs: $($_.Exception.Message)`n"
                    }
                }

                $output += "`n"
            }
        }

        Write-Host $output
    } catch {
        $errorMsg = "ERROR: Could not retrieve service information. $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        $output += "$errorMsg`n"
    }

    return $header + $output
}

function Check-Networks {
    $header = Write-SectionHeader "Network Status"
    $output = ""

    try {
        $networks = docker network ls --filter "driver=overlay" --format "{{.ID}}" 2>$null

        if ($networks.Count -eq 0) {
            $output += "No overlay networks found in the Swarm cluster.`n"
        } else {
            $output += "Overlay Networks:`n"
            $networkList = docker network ls --filter "driver=overlay"
            $output += "$networkList`n`n"

            foreach ($networkId in $networks) {
                $networkInfo = docker network inspect $networkId --format "{{json .}}" | ConvertFrom-Json

                $output += "Network: $($networkInfo.Name) (ID: $($networkId.Substring(0, 12)))`n"
                $output += "  Driver: $($networkInfo.Driver)`n"
                $output += "  Scope: $($networkInfo.Scope)`n"

                if ($networkInfo.IPAM.Config.Count -gt 0) {
                    $subnet = $networkInfo.IPAM.Config[0].Subnet
                    $output += "  Subnet: $subnet`n"
                }

                if ($DetailedReport) {
                    # Check for containers connected to the network
                    if ($networkInfo.Containers) {
                        $output += "  Connected Containers: $($networkInfo.Containers.Count)`n"
                        foreach ($containerId in $networkInfo.Containers.PSObject.Properties.Name) {
                            $container = $networkInfo.Containers.$containerId
                            $output += "    - $($container.Name) (IP: $($container.IPv4Address))`n"
                        }
                    } else {
                        $output += "  Connected Containers: 0`n"
                    }
                }

                $output += "`n"
            }
        }

        Write-Host $output
    } catch {
        $errorMsg = "ERROR: Could not retrieve network information. $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        $output += "$errorMsg`n"
    }

    return $header + $output
}

function Check-Volumes {
    $header = Write-SectionHeader "Volume Status"
    $output = ""

    try {
        $volumes = docker volume ls --format "{{.Name}}" 2>$null

        if ($volumes.Count -eq 0) {
            $output += "No volumes found.`n"
        } else {
            $output += "Volumes:`n"
            $volumeList = docker volume ls
            $output += "$volumeList`n`n"

            if ($DetailedReport) {
                foreach ($volumeName in $volumes) {
                    $volumeInfo = docker volume inspect $volumeName --format "{{json .}}" | ConvertFrom-Json

                    $output += "Volume: $volumeName`n"
                    $output += "  Driver: $($volumeInfo.Driver)`n"
                    $output += "  Mountpoint: $($volumeInfo.Mountpoint)`n"

                    # Check volume labels
                    if ($volumeInfo.Labels) {
                        $output += "  Labels:`n"
                        foreach ($label in $volumeInfo.Labels.PSObject.Properties) {
                            $output += "    $($label.Name): $($label.Value)`n"
                        }
                    }

                    $output += "`n"
                }
            }
        }

        Write-Host $output
    } catch {
        $errorMsg = "ERROR: Could not retrieve volume information. $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        $output += "$errorMsg`n"
    }

    return $header + $output
}

function Check-DockerVersion {
    $header = Write-SectionHeader "Docker Version Compatibility"
    $output = ""

    try {
        $versionInfo = docker version --format "{{json .}}" | ConvertFrom-Json

        $output += "Client Version: $($versionInfo.Client.Version)`n"
        $output += "Server Version: $($versionInfo.Server.Version)`n"

        # Compare versions
        $clientVersion = $versionInfo.Client.Version
        $serverVersion = $versionInfo.Server.Version

        if ($clientVersion -ne $serverVersion) {
            $output += "WARNING: Client and server versions do not match.`n"
            $output += "Version mismatch may cause unexpected behavior.`n"
        } else {
            $output += "Client and server versions match.`n"
        }

        # Check API version compatibility
        $output += "API Version (Client): $($versionInfo.Client.APIVersion)`n"
        $output += "API Version (Server): $($versionInfo.Server.APIVersion)`n"

        if ($versionInfo.Client.APIVersion -ne $versionInfo.Server.APIVersion) {
            $output += "WARNING: Client and server API versions do not match.`n"
        }

        Write-Host $output
    } catch {
        $errorMsg = "ERROR: Could not retrieve Docker version information. $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        $output += "$errorMsg`n"
    }

    return $header + $output
}

# Main script
try {
    Write-Host "Starting Docker Swarm diagnostics..." -ForegroundColor Green
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Green

    $report = "# Docker Swarm Diagnostic Report`n"
    $report += "Generated: $(Get-Date)`n"
    $report += "Hostname: $(hostname)`n"

    # Run diagnostic checks
    $report += Check-DockerDaemon
    $report += Check-DockerVersion
    $report += Check-SwarmStatus
    $report += Check-Nodes
    $report += Check-Services
    $report += Check-Networks
    $report += Check-Volumes

    # Add recommendations section
    $report += Write-SectionHeader "Recommendations"
    $report += "Based on the diagnostic results, here are some recommendations:`n"

    # Check if Swarm is active
    if ($report -match "Swarm Mode: Active") {
        $report += "- Swarm mode is active and operational.`n"
    } else {
        $report += "- Swarm mode is not active. Initialize or join a Swarm cluster.`n"
    }

    # Check for failed tasks
    if ($report -match "WARNING: .+ tasks are in a failed state") {
        $report += "- Some tasks are in a failed state. Check service logs for details.`n"
        $report += "  Use 'docker service logs <service-name>' to view logs.`n"
    }

    # Check for node issues
    if ($report -match "WARNING: Node is not in ready state") {
        $report += "- One or more nodes are not in ready state. Check node connectivity and status.`n"
        $report += "  Use 'docker node update --availability active <node-id>' to reactivate nodes.`n"
    }

    # Add general recommendations
    $report += "- Regularly backup your Swarm configuration using the Backup-SwarmDeployment.ps1 script.`n"
    $report += "- Monitor resource usage on all nodes to prevent resource constraints.`n"
    $report += "- Consider using secrets for sensitive information instead of environment variables.`n"

    # Save report to file if requested
    if ($OutputFile) {
        $report | Out-File -FilePath $OutputFile -Encoding utf8 -Force
        Write-Host "`nDiagnostic report saved to: $OutputFile" -ForegroundColor Green
    }

    Write-Host "`nDiagnostic check completed" -ForegroundColor Green
} catch {
    Write-Error "Error running diagnostics: $_"
    exit 1
}
