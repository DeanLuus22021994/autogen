# Deploy-SwarmStack.ps1
<#
.SYNOPSIS
    Deploys a Docker Swarm stack using a configuration file.

.DESCRIPTION
    This script deploys a Docker Swarm stack using a configuration file that specifies
    the stack name, deployment template, environment variables, and other settings.

.PARAMETER ConfigFile
    The path to the configuration file.

.PARAMETER StackName
    Optional. The name of the stack to deploy. Overrides the stack name in the configuration file.

.EXAMPLE
    .\Deploy-SwarmStack.ps1 -ConfigFile .\configs\default.config.json

.EXAMPLE
    .\Deploy-SwarmStack.ps1 -ConfigFile .\configs\gpu-inference.config.json -StackName ml-inference
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ConfigFile,

    [Parameter(Mandatory = $false)]
    [string]$StackName
)

# Check if config file exists
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Configuration file not found: $ConfigFile"
    exit 1
}

try {
    # Load configuration
    $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json

    # Override stack name if provided
    if ($StackName) {
        $config.stackName = $StackName
    }

    # Verify required configuration
    if (-not $config.stackName) {
        Write-Error "Stack name is not specified in the configuration file"
        exit 1
    }

    if (-not $config.deploymentTemplate) {
        Write-Error "Deployment template is not specified in the configuration file"
        exit 1
    }

    # Verify deployment template exists
    $templatePath = $config.deploymentTemplate
    if (-not [System.IO.Path]::IsPathRooted($templatePath)) {
        $templatePath = Join-Path (Split-Path $ConfigFile) $templatePath
    }

    if (-not (Test-Path $templatePath)) {
        Write-Error "Deployment template not found: $templatePath"
        exit 1
    }

    # Build environment variable string
    $envVars = @()
    if ($config.environment -and $config.environment.PSObject.Properties.Count -gt 0) {
        foreach ($prop in $config.environment.PSObject.Properties) {
            $envVars += "--env `"$($prop.Name)=$($prop.Value)`""
        }
    }

    # Deploy the stack
    Write-Host "Deploying stack '$($config.stackName)' using template: $templatePath" -ForegroundColor Green

    # Create deployment command
    $deployCmd = "docker stack deploy --compose-file `"$templatePath`" $($envVars -join ' ') --prune $($config.stackName)"

    # Execute deployment
    Write-Host "Executing: $deployCmd" -ForegroundColor Yellow
    Invoke-Expression $deployCmd

    # Verify deployment
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Stack '$($config.stackName)' deployed successfully" -ForegroundColor Green

        # Display services
        Write-Host "Services in stack '$($config.stackName)':" -ForegroundColor Cyan
        docker service ls --filter "name=$($config.stackName)"
    } else {
        Write-Error "Failed to deploy stack '$($config.stackName)'"
        exit 1
    }

} catch {
    Write-Error "Error deploying stack: $_"
    exit 1
}
