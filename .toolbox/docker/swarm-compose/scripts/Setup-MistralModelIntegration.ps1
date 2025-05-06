# Setup-MistralModelIntegration.ps1
<#
.SYNOPSIS
    Sets up the integration between Docker Swarm Compose and Docker Model Runner for Mistral models.

.DESCRIPTION
    This script connects the Docker Swarm Compose workspace with Docker Model Runner for Mistral models,
    configuring the necessary DIR.TAG files, environment variables, and providing seamless integration.

.PARAMETER RefreshCache
    Optional. If specified, refreshes the model cache before setting up the integration.

.PARAMETER LogFile
    Optional. The path to the log file. Default is "./mistral-integration-setup.log".

.EXAMPLE
    .\Setup-MistralModelIntegration.ps1

.EXAMPLE
    .\Setup-MistralModelIntegration.ps1 -RefreshCache -LogFile "C:\Logs\mistral-setup.log"
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$RefreshCache,

    [Parameter(Mandatory = $false)]
    [string]$LogFile = "./mistral-integration-setup.log"
)

$ErrorActionPreference = 'Stop'
$GREEN = [ConsoleColor]::Green
$YELLOW = [ConsoleColor]::Yellow
$RED = [ConsoleColor]::Red
$CYAN = [ConsoleColor]::Cyan
$WHITE = [ConsoleColor]::White

function Write-Log {
    <#
    .SYNOPSIS
        Writes a log message to both the console and a log file.

    .DESCRIPTION
        Writes a timestamped log message to both the console with the specified color
        and to the log file specified in the script parameters.

    .PARAMETER Message
        The message to log.

    .PARAMETER Color
        The console color to use for the message. Default is White.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"

    # Write to console
    Write-Host $logMessage -ForegroundColor $Color

    # Write to log file
    Add-Content -Path $LogFile -Value $logMessage
}

function Set-DirTagEntry {
    <#
    .SYNOPSIS
        Creates or updates a DIR.TAG file with specified TODO items and status.

    .DESCRIPTION
        Creates a new DIR.TAG file if it doesn't exist, or updates an existing one,
        with specified TODO items, status, and description according to the project standards.

    .PARAMETER DirTagPath
        The full path to the DIR.TAG file to create or update.

    .PARAMETER TodoItem
        The TODO item to add or update in the DIR.TAG file.

    .PARAMETER Status
        The status of the TODO item (e.g., "DONE", "NOT_STARTED", "PARTIALLY_COMPLETE").

    .PARAMETER Description
        A description of the directory or TODO item to include in the DIR.TAG file.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$DirTagPath,

        [Parameter(Mandatory = $true)]
        [string]$TodoItem,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path $DirTagPath)) {
        Write-Log "DIR.TAG file not found at $DirTagPath. Creating new file." -Color $YELLOW

        $guid = [System.Guid]::NewGuid().ToString()
        $dirPath = Split-Path -Parent $DirTagPath
        $indexPath = $dirPath.Replace('\', '/')

        $content = @"
#INDEX: $indexPath
#GUID: $guid
#TODO:
  - $TodoItem [$Status]

status: PARTIALLY_COMPLETE
updated: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
description: |
  $Description
"@

        Set-Content -Path $DirTagPath -Value $content
        Write-Log "Created new DIR.TAG file at $DirTagPath" -Color $GREEN
    } else {
        Write-Log "Updating existing DIR.TAG file at $DirTagPath" -Color $CYAN

        $content = Get-Content -Path $DirTagPath -Raw

        # Update TODO item if it exists or add it if it doesn't
        if ($content -match "#TODO:(\s*.*?)\r?\n\r?\nstatus:") {
            $todoSection = $Matches[1]

            if ($todoSection -match "  - $TodoItem \[[A-Z_]+\]") {
                $content = $content -replace "  - $TodoItem \[[A-Z_]+\]", "  - $TodoItem [$Status]"
            } else {
                $content = $content -replace "#TODO:(\s*.*?)\r?\n\r?\nstatus:", "#TODO:$1`n  - $TodoItem [$Status]`n`nstatus:"
            }
        }

        # Update updated timestamp
        $content = $content -replace "updated: [0-9TZ:-]+", "updated: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")"

        # Update description if needed
        if ($Description -and (-not ($content -match $Description.Replace("|", "\|")))) {
            $content = $content -replace "description: \|(\s*.*?)$", "description: |$1`n  $Description"
        }

        Set-Content -Path $DirTagPath -Value $content
        Write-Log "Updated DIR.TAG file at $DirTagPath" -Color $GREEN
    }
}

function Test-DockerModelRunner {
    <#
    .SYNOPSIS
        Tests if Docker Model Runner is properly configured.

    .DESCRIPTION
        Verifies that Docker is running and Docker Model Runner is properly configured
        with the necessary models for Mistral integration.

    .OUTPUTS
        [Boolean] True if Docker Model Runner is properly configured, false otherwise.
    #>
    Write-Log "Checking Docker Model Runner setup..." -Color $CYAN

    try {
        # Check if Docker is running
        docker info | Out-Null

        # Check Docker Model Runner setup
        $setupScript = Join-Path $PSScriptRoot "..\..\..\Setup-DockerModelRunner.ps1"

        if (Test-Path $setupScript) {
            Write-Log "Running Docker Model Runner setup script..." -Color $CYAN
            & $setupScript -CheckOnly

            if ($LASTEXITCODE -ne 0) {
                Write-Log "Docker Model Runner is not properly configured. Setting it up..." -Color $YELLOW
                & $setupScript -Models "ai/mistral-nemo", "ai/mistral"

                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Failed to set up Docker Model Runner. Please set it up manually." -Color $RED
                    return $false
                }
            }

            Write-Log "Docker Model Runner is properly configured." -Color $GREEN
            return $true
        } else {
            Write-Log "Docker Model Runner setup script not found at $setupScript" -Color $RED
            return $false
        }
    } catch {
        Write-Log "Error checking Docker Model Runner: $_" -Color $RED
        return $false
    }
}

function Initialize-ModelIntegration {
    <#
    .SYNOPSIS
        Initializes the model integration environment.

    .DESCRIPTION
        Creates the necessary directory structure and configuration files for
        integrating Docker Swarm Compose with Docker Model Runner for Mistral models.

    .OUTPUTS
        [Boolean] True if initialization was successful, false otherwise.
    #>
    # Create directory for model integration if it doesn't exist
    $modelIntegrationDir = Join-Path $PSScriptRoot "..\model-integration"

    if (-not (Test-Path $modelIntegrationDir)) {
        New-Item -Path $modelIntegrationDir -ItemType Directory -Force | Out-Null
        Write-Log "Created model integration directory at $modelIntegrationDir" -Color $GREEN
    }

    # Create DIR.TAG file for model integration directory
    $dirTagPath = Join-Path $modelIntegrationDir "DIR.TAG"
    Set-DirTagEntry -DirTagPath $dirTagPath -TodoItem "Setup Mistral model integration" -Status "DONE" -Description "Integration between Docker Swarm Compose and Docker Model Runner for Mistral models."

    # Create environment variables file
    $envFilePath = Join-Path $modelIntegrationDir "mistral-environment.json"
    $envConfig = @{
        modelRunnerEndpoint = "http://model-runner.docker.internal/engines/v1/chat/completions"
        models = @{
            mistralNemo = "ai/mistral-nemo"
            mistral = "ai/mistral"
        }
        defaultSettings = @{
            quantization = "int8"
            gpuCount = 1
            contextLength = 8192
            tensorParallelSize = 1
        }
        swarmIntegration = @{
            stackName = "autogen-mistral"
            apiPort = 8080
            monitoringPort = 9090
        }
    }

    $envConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $envFilePath
    Write-Log "Created environment configuration file at $envFilePath" -Color $GREEN

    # Create symbolic link to Docker Model Runner script for easy access
    $sourceScript = Join-Path $PSScriptRoot "..\..\..\Setup-DockerModelRunner.ps1"
    $targetScript = Join-Path $modelIntegrationDir "Setup-DockerModelRunner.ps1"

    if (Test-Path $sourceScript) {
        if (-not (Test-Path $targetScript)) {
            # Create a copy instead of a symlink for better compatibility
            Copy-Item -Path $sourceScript -Destination $targetScript
            Write-Log "Created copy of Docker Model Runner setup script at $targetScript" -Color $GREEN
        }
    } else {
        Write-Log "Docker Model Runner setup script not found at $sourceScript" -Color $YELLOW
    }

    # Create metadata file for integration status
    $metadataFilePath = Join-Path $modelIntegrationDir "integration-metadata.json"
    $metadata = @{
        integratedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        version = "1.0.0"
        docModelRunnerCompatible = $true
        mistralModels = @("ai/mistral-nemo", "ai/mistral")
        swarmCompatible = $true
    }

    $metadata | ConvertTo-Json | Set-Content -Path $metadataFilePath
    Write-Log "Created integration metadata file at $metadataFilePath" -Color $GREEN

    return $true
}

function Test-ModelIntegration {
    <#
    .SYNOPSIS
        Tests the model integration setup.

    .DESCRIPTION
        Verifies that the Docker Model Runner endpoint is accessible and
        Mistral models are available.

    .OUTPUTS
        [Boolean] True if integration is working correctly, false otherwise.
    #>
    Write-Log "Testing model integration..." -Color $CYAN

    try {
        # Test Docker Model Runner endpoint
        $modelRunnerEndpoint = "http://model-runner.docker.internal/engines"
        $response = Invoke-WebRequest -Uri $modelRunnerEndpoint -UseBasicParsing -ErrorAction SilentlyContinue

        if ($response.StatusCode -eq 200) {
            Write-Log "✅ Docker Model Runner endpoint is accessible." -Color $GREEN

            # Parse the JSON response to get available models
            $availableModels = $response.Content | ConvertFrom-Json

            # Check if Mistral models are available
            $mistralAvailable = $availableModels -contains "ai/mistral-nemo" -or $availableModels -contains "ai/mistral"

            if ($mistralAvailable) {
                Write-Log "✅ Mistral models are available in Docker Model Runner." -Color $GREEN
                return $true
            } else {
                Write-Log "❌ Mistral models are not available in Docker Model Runner." -Color $RED
                return $false
            }
        } else {
            Write-Log "❌ Docker Model Runner endpoint is not accessible (Status code: $($response.StatusCode))." -Color $RED
            return $false
        }
    } catch {
        Write-Log "❌ Error testing model integration: $_" -Color $RED
        return $false
    }
}

function Update-MainDirTag {
    <#
    .SYNOPSIS
        Updates the main DIR.TAG file with Mistral integration status.

    .DESCRIPTION
        Updates the main DIR.TAG file in the swarm-compose directory to indicate
        that the Mistral model integration has been completed.
    #>
    # Update main DIR.TAG file with Mistral integration status
    $mainDirTagPath = Join-Path $PSScriptRoot "..\DIR.TAG"

    if (Test-Path $mainDirTagPath) {
        Set-DirTagEntry -DirTagPath $mainDirTagPath -TodoItem "Integrate with Docker Model Runner" -Status "DONE" -Description "Integration with Docker Model Runner for Mistral models."
        Write-Log "Updated main DIR.TAG file with Mistral integration status." -Color $GREEN
    }
}

# Main script
try {
    # Initialize log file
    if (Test-Path $LogFile) {
        Remove-Item -Path $LogFile -Force
    }    Write-Log "Starting Mistral Model integration setup..." -Color $CYAN
    Write-Log "Timestamp: $(Get-Date)" -Color $WHITE

    # Check Docker Model Runner setup
    $modelRunnerSetup = Test-DockerModelRunner

    if (-not $modelRunnerSetup) {
        Write-Log "Failed to ensure Docker Model Runner setup. Integration may not work properly." -Color $YELLOW
    }

    # Refresh cache if requested
    if ($RefreshCache) {
        Write-Log "Refreshing model cache..." -Color $CYAN
        # Clear any existing cache
        $modelIntegrationDir = Join-Path $PSScriptRoot "..\model-integration"

        if (Test-Path $modelIntegrationDir) {
            Remove-Item -Path $modelIntegrationDir -Recurse -Force            Write-Log "Cleared existing model integration cache." -Color $GREEN
        }
    }

    # Set up model integration
    $integrationSetup = Initialize-ModelIntegration

    if ($integrationSetup) {
        # Test the integration
        $integrationTest = Test-ModelIntegration

        if ($integrationTest) {
            # Update main DIR.TAG file            Update-MainDirTag

            Write-Log "🎉 Mistral Model integration setup completed successfully!" -Color $GREEN
            Write-Log "You can now deploy the optimized Mistral model using the Start-MistralGPURunner.ps1 script." -Color $CYAN
        } else {
            Write-Log "⚠️ Mistral Model integration setup completed, but integration test failed." -Color $YELLOW
            Write-Log "You may need to manually set up Docker Model Runner with the required Mistral models." -Color $YELLOW
        }
    } else {
        Write-Log "❌ Failed to set up Mistral Model integration." -Color $RED
    }
} catch {
    Write-Log "❌ Error setting up Mistral Model integration: $_" -Color $RED
    exit 1
}
