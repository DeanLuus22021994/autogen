# .github/linting/core/MarkdownLintUtilities.psm1
# Common utilities for markdown linting

using namespace System.IO
using namespace System.Management.Automation

<#
.SYNOPSIS
    Provides common utilities for markdown linting operations.
.DESCRIPTION
    A set of functions to support markdown linting initialization,
    configuration management, and execution.
#>

# cSpell:ignore esac

# Import error handling utilities
$ErrorHandlingModule = Join-Path -Path $PSScriptRoot -ChildPath '..\utils\ErrorHandling.psm1'
if (Test-Path -Path $ErrorHandlingModule) {
    Import-Module $ErrorHandlingModule -Force
}

# Import configuration provider
$ConfigProviderModule = Join-Path -Path $PSScriptRoot -ChildPath 'ConfigurationProvider.psm1'
if (Test-Path -Path $ConfigProviderModule) {
    Import-Module $ConfigProviderModule -Force
}

function Assert-MarkdownLintDependencies {
    <#
    .SYNOPSIS
        Verifies that all required dependencies are installed.
    .DESCRIPTION
        Checks for necessary tools and packages required for markdown linting.
    .OUTPUTS
        [bool] True if all dependencies are available, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $dependencies = @(
        @{Name = "node"; Command = "node --version"; Message = "Node.js is required for markdown linting" },
        @{Name = "npm"; Command = "npm --version"; Message = "npm is required for package management" },
        @{Name = "markdownlint-cli2"; Command = "npx markdownlint-cli2 --version"; Message = "markdownlint-cli2 is required" }
    )

    $allDepsAvailable = $true

    foreach ($dep in $dependencies) {
        try {
            $null = Invoke-Expression $dep.Command -ErrorAction Stop
            Write-Verbose "✓ $($dep.Name) is installed"
        } catch {
            $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "checking for $($dep.Name)"
            Write-Warning "$($dep.Message): $errorMessage"
            $allDepsAvailable = $false
        }
    }

    return $allDepsAvailable
}

function Initialize-MarkdownLintConfiguration {
    <#
    .SYNOPSIS
        Initializes the markdown linting configuration.
    .DESCRIPTION
        Sets up configuration files and ensures they are properly structured.
    .PARAMETER ConfigPath
        Path to the configuration file.
    .PARAMETER Force
        If set, overwrites existing configuration.
    .OUTPUTS
        [bool] True if initialization was successful, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter()]
        [switch]$Force
    )

    # Get configuration directory
    $configDir = Split-Path -Path $ConfigPath -Parent

    # Create the directory if it doesn't exist
    if (-not (Test-Path -Path $configDir)) {
        try {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            Write-Verbose "Created directory: $configDir"
        }
        catch {
            $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "creating configuration directory"
            Write-Warning $errorMessage
            return $false
        }
    }

    if (-not (Test-Path $ConfigPath) -or $Force) {
        Write-Verbose "Creating default configuration at $ConfigPath"

        # Import config module to generate default configuration
        $configModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'MarkdownLintConfig.psm1'
        Import-Module $configModulePath -Force -ErrorAction SilentlyContinue

        try {
            # Generate and save the default configuration
            $defaultConfig = Get-DefaultMarkdownLintConfig
            $defaultConfig | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Force
            Write-Verbose "Default configuration created successfully"
        }
        catch {
            $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "creating default configuration"
            Write-Warning $errorMessage
            return $false
        }
    } else {
        Write-Verbose "Using existing configuration at $ConfigPath"
    }

    # Validate configuration
    try {
        $configContent = Get-Content $ConfigPath -Raw
        $null = $configContent | ConvertFrom-Json
        Write-Verbose "Configuration validated successfully"
        return $true
    } catch {
        $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "validating configuration"
        Write-Warning "Invalid configuration format: $errorMessage"
        return $false
    }
}

function Register-MarkdownLintVSCodeTasks {
    <#
    .SYNOPSIS
        Registers markdown linting tasks with VS Code.
    .DESCRIPTION
        Creates or updates VS Code task configuration for markdown linting.
    .OUTPUTS
        [bool] True if registration was successful, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Import the VS Code integration module
    $vsCodeModulePath = Join-Path -Path (Split-Path $PSScriptRoot) -ChildPath "scripts\Update-VsCodeConfig.ps1"
    if (Test-Path $vsCodeModulePath) {
        try {
            . $vsCodeModulePath
            Update-VsCodeTasksConfiguration
            return $true
        }
        catch {
            $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "updating VS Code tasks"
            Write-Warning $errorMessage

            # Attempt fallback implementation
            return New-FallbackVSCodeTasks
        }
    } else {
        Write-Warning "VS Code integration module not found at $vsCodeModulePath"
        return New-FallbackVSCodeTasks
    }
}

function New-FallbackVSCodeTasks {
    <#
    .SYNOPSIS
        Creates basic VS Code tasks as a fallback.
    .DESCRIPTION
        Sets up minimum VS Code task configuration when the main module is unavailable.
    .OUTPUTS
        [bool] True if tasks were created successfully, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Fallback implementation
    $vscodePath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath ".." -AdditionalChildPath "..") -ChildPath ".vscode"
    $tasksPath = Join-Path -Path $vscodePath -ChildPath "tasks.json"

    try {
        if (-not (Test-Path -Path $vscodePath)) {
            New-Item -Path $vscodePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -Path $tasksPath)) {
            # Create new tasks file
            @{
                version = "2.0.0"
                tasks = @(
                    @{
                        label = "Lint Markdown"
                        type = "shell"
                        command = "npx markdownlint-cli2 '**/*.md'"
                        problemMatcher = @()
                        group = @{
                            kind = "build"
                            isDefault = $false
                        }
                    }
                )
            } | ConvertTo-Json -Depth 4 | Out-File -FilePath $tasksPath -Force

            Write-Verbose "Created VS Code tasks configuration"
            return $true
        }
        return $true
    }
    catch {
        $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "creating fallback VS Code tasks"
        Write-Warning $errorMessage
        return $false
    }
}

function Invoke-ShellCommandProcessing {
    <#
    .SYNOPSIS
        Processes shell commands with proper handling of special keywords.
    .DESCRIPTION
        Ensures shell script syntax is properly handled, including bash-specific
        keywords like 'esac' (which is 'case' spelled backwards, used to end
        case statements in shell scripts).
    .PARAMETER Command
        The shell command to process.
    .OUTPUTS
        [string] The processed command.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    # Import the shell processing module if available
    $shellModulePath = Join-Path -Path (Split-Path $PSScriptRoot) -ChildPath "scripts\Invoke-ShellCommand.ps1"
    if (Test-Path -Path $shellModulePath) {
        try {
            . $shellModulePath
            return Invoke-ShellCommand -Command $Command
        }
        catch {
            $errorMessage = Get-FormattedErrorMessage -ErrorRecord $_ -Context "formatting shell command"
            Write-Warning $errorMessage
            # Fall through to fallback implementation
        }
    }

    # Fallback implementation
    # Handle shell commands, including those with case statements
    # In shell scripts, "case" blocks end with "esac" (case spelled backwards)
    $casePattern = [regex]::new('case\s+.+\s+in\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($casePattern.IsMatch($Command)) {
        # This is a valid shell case statement
        return $Command
    }

    return $Command
}

# Export functions
Export-ModuleMember -Function @(
    'Assert-MarkdownLintDependencies',
    'Initialize-MarkdownLintConfiguration',
    'Register-MarkdownLintVSCodeTasks',
    'Invoke-ShellCommandProcessing'
)