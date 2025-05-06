# Setup-LegalAnalysisModels.ps1
<#
.SYNOPSIS
    Sets up Docker Model Runner with models required for legal document analysis.

.DESCRIPTION
    This script configures Docker Model Runner with the specific models needed for legal document analysis.
    It pulls the required models and verifies their availability.

.PARAMETER Force
    If specified, forces a re-pull of models even if they already exist.

.EXAMPLE
    .\Setup-LegalAnalysisModels.ps1

.EXAMPLE
    .\Setup-LegalAnalysisModels.ps1 -Force
#>
[CmdletBinding()]
param (
    [Parameter()]
    [switch]$Force
)

$scriptsRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptsRoot
$modelSetupScript = Join-Path $repoRoot "Setup-DockerModelRunner.ps1"

# Models required for legal document analysis
$requiredModels = @("ai/mistral-nemo", "ai/mistral", "ai/llama3")

Write-Host "Setting up models for legal document analysis..." -ForegroundColor Cyan

# Check if the setup script exists
if (-not (Test-Path $modelSetupScript)) {
    Write-Host "❌ Could not find Docker Model Runner setup script at: $modelSetupScript" -ForegroundColor Red
    Write-Host "Please ensure you're running this script from the .toolbox\docker\legal-analysis directory" -ForegroundColor Yellow
    exit 1
}

# Run the Docker Model Runner setup script with required models
Write-Host "Running Docker Model Runner setup with required models..." -ForegroundColor Cyan
$modelArgs = @("-Models", [string]::Join(",", $requiredModels))

if ($Force) {
    $modelArgs += "-Force"
}

# Call the main model setup script
& $modelSetupScript @modelArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to set up Docker Model Runner models for legal analysis" -ForegroundColor Red
    exit 1
}

# Verify that models are available for legal analysis
Write-Host "✅ Docker Model Runner is configured with the necessary models for legal document analysis" -ForegroundColor Green

# Create a configuration marker file
$configMarker = Join-Path $PSScriptRoot "models-configured.tag"
Set-Content -Path $configMarker -Value (Get-Date)

Write-Host "Legal Analysis system is ready to use!" -ForegroundColor Green
Write-Host "You can now run the VS Code tasks in the 'Legal Analysis' section" -ForegroundColor Cyan
