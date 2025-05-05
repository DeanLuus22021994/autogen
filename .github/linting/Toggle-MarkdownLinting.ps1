# Script to quickly toggle markdown linting on/off

<#
.SYNOPSIS
    Toggles markdown linting on or off.
.DESCRIPTION
    Provides a simple interface to enable or disable markdown linting
    by updating VS Code settings or the configuration file.
.PARAMETER Enable
    Enables linting if specified. Cannot be used with -Disable.
.PARAMETER Disable
    Disables linting if specified. Cannot be used with -Enable.
.PARAMETER Status
    Shows the current linting status without changing anything.
.EXAMPLE
    .\Toggle-MarkdownLinting.ps1 -Disable
    Turns off markdown linting.
.EXAMPLE
    .\Toggle-MarkdownLinting.ps1 -Enable
    Turns on markdown linting.
.EXAMPLE
    .\Toggle-MarkdownLinting.ps1 -Status
    Shows the current markdown linting status.
#>
[CmdletBinding(DefaultParameterSetName = 'Toggle')]
param(
    [Parameter(ParameterSetName = 'Enable', Mandatory = $false)]
    [switch]$Enable,

    [Parameter(ParameterSetName = 'Disable', Mandatory = $false)]
    [switch]$Disable,

    [Parameter(ParameterSetName = 'Status', Mandatory = $false)]
    [switch]$Status
)

# Get the directory of the current script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Import helper module if it exists
$helperModulePath = Join-Path -Path $scriptPath -ChildPath "MarkdownLintHelpers.psm1"
if (Test-Path -Path $helperModulePath) {
    Import-Module -Name $helperModulePath -Force
    Write-Verbose "Imported helper module: $helperModulePath"
}

function Get-LintingStatus {
    [CmdletBinding()]
    param()

    $vscodeSettingsPath = Join-Path -Path $repoRoot -ChildPath ".vscode\settings.json"

    if (-not (Test-Path -Path $vscodeSettingsPath)) {
        return @{
            Enabled = $true  # Default to enabled if there's no settings file
            InSettings = $false
        }
    }

    try {
        $settings = Get-Content -Path $vscodeSettingsPath -Raw | ConvertFrom-Json -ErrorAction Stop

        # Check if markdownlint.enabled property exists and is not null
        if (Get-Member -InputObject $settings -Name "markdownlint.enabled" -MemberType NoteProperty) {
            return @{
                Enabled = [bool]$settings."markdownlint.enabled"
                InSettings = $true
            }
        }
        else {
            return @{
                Enabled = $true  # Default to enabled if property doesn't exist
                InSettings = $false
            }
        }
    }
    catch {
        Write-Warning "Error reading VS Code settings: $_"
        return @{
            Enabled = $true  # Default to enabled on error
            InSettings = $false
        }
    }
}

function Set-LintingStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )

    $vscodeDir = Join-Path -Path $repoRoot -ChildPath ".vscode"
    $vscodeSettingsPath = Join-Path -Path $vscodeDir -ChildPath "settings.json"

    # Create .vscode directory if it doesn't exist
    if (-not (Test-Path -Path $vscodeDir)) {
        New-Item -Path $vscodeDir -ItemType Directory -Force | Out-Null
    }

    # Create settings.json if it doesn't exist
    if (-not (Test-Path -Path $vscodeSettingsPath)) {
        Set-Content -Path $vscodeSettingsPath -Value "{}" -Force
    }

    try {
        $settings = Get-Content -Path $vscodeSettingsPath -Raw | ConvertFrom-Json

        # Create a PSCustomObject if settings is null
        if ($null -eq $settings) {
            $settings = [PSCustomObject]@{}
        }

        # Add or update markdownlint.enabled property
        $settings | Add-Member -MemberType NoteProperty -Name "markdownlint.enabled" -Value $Enabled -Force

        # Save settings back to file
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $vscodeSettingsPath -Force

        return $true
    }
    catch {
        Write-Error "Failed to update VS Code settings: $_"
        return $false
    }
}

function Show-LintingStatus {
    [CmdletBinding()]
    param()

    $status = Get-LintingStatus

    if ($status.Enabled) {
        Write-Host "Markdown linting is currently ENABLED." -ForegroundColor Green
    }
    else {
        Write-Host "Markdown linting is currently DISABLED." -ForegroundColor Yellow
    }

    if (-not $status.InSettings) {
        Write-Host "Note: This is the default setting as no explicit configuration was found." -ForegroundColor Cyan
    }

    # Check if VS Code extension is installed
    try {
        $extensions = Invoke-Expression "code --list-extensions" -ErrorAction SilentlyContinue
        if ($extensions -contains "DavidAnson.vscode-markdownlint") {
            Write-Host "VS Code markdownlint extension is installed." -ForegroundColor Green
        }
        else {
            Write-Warning "VS Code markdownlint extension is not installed. Install it for better integration."
        }
    }
    catch {
        Write-Verbose "Could not check VS Code extensions: $_"
    }
}

# Main execution
try {
    if ($Status) {
        Show-LintingStatus
    }
    elseif ($Enable) {
        $result = Set-LintingStatus -Enabled $true
        if ($result) {
            Write-Host "Markdown linting has been ENABLED." -ForegroundColor Green
        }
        Show-LintingStatus
    }
    elseif ($Disable) {
        $result = Set-LintingStatus -Enabled $false
        if ($result) {
            Write-Host "Markdown linting has been DISABLED." -ForegroundColor Yellow
        }
        Show-LintingStatus
    }
    else {
        # No parameter specified, toggle current state
        $currentStatus = Get-LintingStatus
        $newState = -not $currentStatus.Enabled
        $result = Set-LintingStatus -Enabled $newState

        if ($result) {
            if ($newState) {
                Write-Host "Markdown linting has been ENABLED." -ForegroundColor Green
            }
            else {
                Write-Host "Markdown linting has been DISABLED." -ForegroundColor Yellow
            }
        }

        Show-LintingStatus
    }
}
catch {
    Write-Error "Error toggling markdown linting: $_"
    exit 1
}