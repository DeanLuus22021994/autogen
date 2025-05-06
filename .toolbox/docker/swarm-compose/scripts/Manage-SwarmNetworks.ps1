# Manage-SwarmNetworks.ps1
<#
.SYNOPSIS
    Manages Docker Swarm networks.

.DESCRIPTION
    This script provides utilities for managing Docker Swarm networks, including creating, listing, and removing networks.

.PARAMETER Action
    The action to perform: Create, List, or Remove.

.PARAMETER NetworkName
    The name of the network to create or remove. Required for Create and Remove actions.

.PARAMETER Driver
    Optional. The network driver to use. Default is 'overlay'.

.PARAMETER Attachable
    Optional. If specified, the network will be attachable by containers.

.PARAMETER Encrypted
    Optional. If specified, the network traffic will be encrypted.

.PARAMETER Subnet
    Optional. The subnet to use for the network (e.g., 172.28.0.0/16).

.EXAMPLE
    .\Manage-SwarmNetworks.ps1 -Action List

.EXAMPLE
    .\Manage-SwarmNetworks.ps1 -Action Create -NetworkName autogen-network -Attachable -Encrypted

.EXAMPLE
    .\Manage-SwarmNetworks.ps1 -Action Remove -NetworkName autogen-network
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('Create', 'List', 'Remove')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$NetworkName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('overlay', 'bridge', 'macvlan', 'ipvlan')]
    [string]$Driver = 'overlay',

    [Parameter(Mandatory = $false)]
    [switch]$Attachable,

    [Parameter(Mandatory = $false)]
    [switch]$Encrypted,

    [Parameter(Mandatory = $false)]
    [string]$Subnet
)

function Format-NetworkDetails {
    param ([string]$Network)

    $details = docker network inspect $Network --format json | ConvertFrom-Json

    $ipamConfig = if ($details.IPAM.Config.Length -gt 0) {
        $details.IPAM.Config[0].Subnet
    } else {
        "None"
    }

    $attachable = if ($details.Attachable) { "Yes" } else { "No" }

    [PSCustomObject]@{
        Name = $details.Name
        Driver = $details.Driver
        Scope = $details.Scope
        Subnet = $ipamConfig
        Attachable = $attachable
        Services = ($details.Containers | Where-Object { $_ -ne $null }).Count
    }
}

function List-Networks {
    Write-Host "Docker Swarm Networks:" -ForegroundColor Cyan

    $networks = docker network ls --filter "driver=overlay" --format "{{.Name}}"

    if ($networks.Count -eq 0) {
        Write-Host "No overlay networks found" -ForegroundColor Yellow
        return
    }

    $networkDetails = @()
    foreach ($network in $networks) {
        $networkDetails += Format-NetworkDetails -Network $network
    }

    $networkDetails | Format-Table -AutoSize -Property Name, Driver, Scope, Subnet, Attachable, Services
}

function Create-Network {
    param (
        [string]$Name,
        [string]$NetworkDriver,
        [bool]$IsAttachable,
        [bool]$IsEncrypted,
        [string]$NetworkSubnet
    )

    if ([string]::IsNullOrEmpty($Name)) {
        Write-Error "Network name is required for Create action"
        exit 1
    }

    # Check if network already exists
    $networkExists = $null -ne (docker network ls --filter "name=$Name" --format "{{.Name}}" | Where-Object { $_ -eq $Name })

    if ($networkExists) {
        Write-Host "Network '$Name' already exists" -ForegroundColor Yellow
        Format-NetworkDetails -Network $Name | Format-List
        return
    }

    # Build command
    $createCmd = "docker network create --driver $NetworkDriver"

    if ($IsAttachable) {
        $createCmd += " --attachable"
    }

    if ($IsEncrypted) {
        $createCmd += " --opt encrypted=true"
    }

    if (-not [string]::IsNullOrEmpty($NetworkSubnet)) {
        $createCmd += " --subnet $NetworkSubnet"
    }

    $createCmd += " $Name"

    # Create network
    Write-Host "Creating network with command: $createCmd" -ForegroundColor Cyan
    Invoke-Expression $createCmd

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Network '$Name' created successfully" -ForegroundColor Green
        Format-NetworkDetails -Network $Name | Format-List
    } else {
        Write-Error "Failed to create network '$Name'"
        exit 1
    }
}

function Remove-Network {
    param ([string]$Name)

    if ([string]::IsNullOrEmpty($Name)) {
        Write-Error "Network name is required for Remove action"
        exit 1
    }

    # Check if network exists
    $networkExists = $null -ne (docker network ls --filter "name=$Name" --format "{{.Name}}" | Where-Object { $_ -eq $Name })

    if (-not $networkExists) {
        Write-Warning "Network '$Name' does not exist"
        return
    }

    # Check if network is in use
    $networkDetails = Format-NetworkDetails -Network $Name

    if ($networkDetails.Services -gt 0) {
        Write-Warning "Network '$Name' is in use by $($networkDetails.Services) services"
        $confirmation = Read-Host "Do you want to continue with removal? (y/n)"

        if ($confirmation -ne 'y') {
            Write-Host "Operation canceled" -ForegroundColor Yellow
            return
        }
    }

    # Remove network
    Write-Host "Removing network '$Name'..." -ForegroundColor Cyan
    docker network rm $Name

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Network '$Name' removed successfully" -ForegroundColor Green
    } else {
        Write-Error "Failed to remove network '$Name'"
        exit 1
    }
}

# Main script
try {
    switch ($Action) {
        'List' {
            List-Networks
        }

        'Create' {
            Create-Network -Name $NetworkName -NetworkDriver $Driver -IsAttachable $Attachable -IsEncrypted $Encrypted -NetworkSubnet $Subnet
        }

        'Remove' {
            Remove-Network -Name $NetworkName
        }
    }
} catch {
    Write-Error "Error managing Swarm networks: $_"
    exit 1
}
