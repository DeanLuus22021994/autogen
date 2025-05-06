# Start-LegalAnalysisSystem.ps1
<#
.SYNOPSIS
    Starts and configures the legal document analysis system.

.DESCRIPTION
    This script prepares the environment, starts Docker containers, and configures
    the legal document analysis system for processing court docket documents.

.PARAMETER ConfigureOnly
    If specified, only configures the system without starting Docker containers.

.PARAMETER GenerateTestDocuments
    If specified, generates test documents for system testing.

.PARAMETER Force
    If specified, forces recreation of containers and volumes.

.EXAMPLE
    .\Start-LegalAnalysisSystem.ps1

.EXAMPLE
    .\Start-LegalAnalysisSystem.ps1 -GenerateTestDocuments -Force
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$ConfigureOnly,

    [Parameter()]
    [switch]$GenerateTestDocuments,

    [Parameter()]
    [switch]$Force
)

$GREEN = [ConsoleColor]::Green
$YELLOW = [ConsoleColor]::Yellow
$RED = [ConsoleColor]::Red
$CYAN = [ConsoleColor]::Cyan

Write-Host "Legal Document Analysis System Setup" -ForegroundColor $CYAN
Write-Host "=====================================" -ForegroundColor $CYAN

# Function to check Docker installation
function Test-DockerInstallation {
    try {
        $dockerVersion = docker --version
        Write-Host "Docker detected: $dockerVersion" -ForegroundColor $GREEN
        return $true
    }
    catch {
        Write-Host "Docker is not installed or not in PATH." -ForegroundColor $RED
        Write-Host "Please install Docker Desktop from https://www.docker.com/products/docker-desktop/" -ForegroundColor $YELLOW
        return $false
    }
}

# Function to check if a Docker network exists
function Test-DockerNetwork {
    param (
        [string]$NetworkName
    )

    $network = docker network ls --filter name=^${NetworkName}$ --format "{{.Name}}" 2>$null
    return ($network -eq $NetworkName)
}

# Function to create required directories
function Create-RequiredDirectories {
    $directories = @(
        "./incoming-documents",
        "./analysis-results",
        "./config"
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "Created directory: $dir" -ForegroundColor $GREEN
        }
    }

    # Copy config file to config directory if it exists
    $configSource = "./legal-analysis-config.xml"
    $configDest = "./config/legal-analysis-config.xml"

    if (Test-Path $configSource) {
        Copy-Item -Path $configSource -Destination $configDest -Force
        Write-Host "Copied configuration file to config directory" -ForegroundColor $GREEN
    }
}

# Function to start Docker containers
function Start-DockerContainers {
    param (
        [switch]$Force
    )

    Write-Host "Starting Docker containers..." -ForegroundColor $CYAN

    # Check if containers are already running
    $containerRunning = $false
    try {
        $container = docker ps --filter name=legal-analysis --format "{{.Names}}" 2>$null
        $containerRunning = ($container -eq "legal-analysis")
    }
    catch {
        $containerRunning = $false
    }

    if ($containerRunning -and -not $Force) {
        Write-Host "Legal analysis system is already running. Use -Force to recreate containers." -ForegroundColor $YELLOW
        return
    }

    # Stop and remove existing containers if Force is specified
    if ($Force) {
        Write-Host "Stopping and removing existing containers..." -ForegroundColor $YELLOW
        docker-compose down -v 2>$null
    }

    # Ensure docker-internal network exists
    if (-not (Test-DockerNetwork -NetworkName "docker-internal")) {
        Write-Host "Creating docker-internal network..." -ForegroundColor $YELLOW
        docker network create docker-internal
    }

    # Start containers with docker-compose
    try {
        docker-compose up -d
        Write-Host "Docker containers started successfully" -ForegroundColor $GREEN
    }
    catch {
        Write-Host "Error starting Docker containers: $_" -ForegroundColor $RED
        exit 1
    }
}

# Function to generate test documents
function Generate-SampleDocuments {
    Write-Host "Generating test documents..." -ForegroundColor $CYAN

    # Check if Generate-TestDocuments.ps1 exists
    $scriptPath = "./Generate-TestDocuments.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath -OutputFolder "./incoming-documents" -Count 3
    }
    else {
        Write-Host "Test document generator script not found: $scriptPath" -ForegroundColor $RED
    }
}

# Function to update VS Code tasks
function Update-VsCodeTasks {
    Write-Host "Updating VS Code tasks..." -ForegroundColor $CYAN

    # Check if Update-LegalAnalysisTasks.ps1 exists
    $scriptPath = "./Update-LegalAnalysisTasks.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath -Force
    }
    else {
        Write-Host "VS Code tasks update script not found: $scriptPath" -ForegroundColor $RED
    }
}

# Check Docker installation
$dockerInstalled = Test-DockerInstallation
if (-not $dockerInstalled) {
    exit 1
}

# Configure Docker Model Runner
Write-Host "Configuring Docker Model Runner for legal analysis..." -ForegroundColor $CYAN
$setupScript = Join-Path $PSScriptRoot "Setup-LegalAnalysisModels.ps1"
if (Test-Path $setupScript) {
    & $setupScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to configure Docker Model Runner for legal analysis" -ForegroundColor $RED
        Write-Host "Please run the 'Setup Docker Model Runner' task from VS Code before proceeding" -ForegroundColor $YELLOW
        exit 1
    }
}
else {
    Write-Host "Docker Model Runner setup script not found: $setupScript" -ForegroundColor $RED
    Write-Host "Please run the 'Setup Docker Model Runner' task from VS Code before proceeding" -ForegroundColor $YELLOW
}

# Create required directories
Create-RequiredDirectories

# Update VS Code tasks
Update-VsCodeTasks

# Start Docker containers unless ConfigureOnly is specified
if (-not $ConfigureOnly) {
    Start-DockerContainers -Force:$Force
}

# Generate test documents if requested
if ($GenerateTestDocuments) {
    Generate-SampleDocuments
}

Write-Host "`nSystem setup complete" -ForegroundColor $GREEN
Write-Host "------------------------" -ForegroundColor $GREEN
Write-Host "You can now:" -ForegroundColor $CYAN
Write-Host "1. Place legal documents in the 'incoming-documents' folder for automatic processing" -ForegroundColor $CYAN
Write-Host "2. Run 'Process-LegalDocuments.ps1 -InputFile <path>' to process a specific file" -ForegroundColor $CYAN
Write-Host "3. Use VS Code tasks to interact with the system (Press Ctrl+Shift+P and type 'Tasks: Run Task')" -ForegroundColor $CYAN
Write-Host "4. Access the web dashboard at http://localhost:3000" -ForegroundColor $CYAN

if (-not $ConfigureOnly) {
    Write-Host "`nDockers containers are running. Use 'docker-compose down' to stop them when done." -ForegroundColor $YELLOW
}
