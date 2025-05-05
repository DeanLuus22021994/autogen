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

function Assert-MarkdownLintDependencies {
    <#
    .SYNOPSIS
        Verifies that all required dependencies are installed.
    .DESCRIPTION
        Checks for necessary tools and packages required for markdown linting.
    #>
    [CmdletBinding()]
    param()

    $dependencies = @(
        @{Name = "node"; Command = "node --version"; Message = "Node.js is required for markdown linting" },
        @{Name = "npm"; Command = "npm --version"; Message = "npm is required for package management" },
        @{Name = "markdownlint-cli2"; Command = "markdownlint-cli2 --version"; Message = "markdownlint-cli2 is required" }
    )

    foreach ($dep in $dependencies) {
        try {
            $null = Invoke-Expression $dep.Command -ErrorAction Stop
            Write-Verbose "✓ $($dep.Name) is installed"
        } catch {
            throw $dep.Message
        }
    }
}

function Initialize-MarkdownLintConfiguration {
    <#
    .SYNOPSIS
        Initializes the markdown linting configuration.
    .DESCRIPTION
        Sets up configuration files and ensures they are properly structured.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter()]
        [switch]$Force
    )

    if (-not (Test-Path $ConfigPath) -or $Force) {
        Write-Verbose "Creating default configuration at $ConfigPath"

        # Import config module to generate default configuration
        $configModulePath = Join-Path (Split-Path $PSScriptRoot) "core\MarkdownLintConfig.psm1"
        Import-Module $configModulePath -Force

        # Generate and save the default configuration
        $defaultConfig = Get-DefaultMarkdownLintConfig
        $defaultConfig | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Force
    } else {
        Write-Verbose "Using existing configuration at $ConfigPath"
    }

    # Validate configuration
    $configContent = Get-Content $ConfigPath -Raw
    try {
        $null = $configContent | ConvertFrom-Json
        Write-Verbose "Configuration validated successfully"
    } catch {
        throw "Invalid configuration format: $_"
    }
}

function Register-MarkdownLintVSCodeTasks {
    <#
    .SYNOPSIS
        Registers markdown linting tasks with VS Code.
    .DESCRIPTION
        Creates or updates VS Code task configuration for markdown linting.
    #>
    [CmdletBinding()]
    param()

    # Import the VS Code integration module
    $vsCodeModulePath = Join-Path (Split-Path $PSScriptRoot) "scripts\Update-VsCodeConfig.ps1"
    if (Test-Path $vsCodeModulePath) {
        . $vsCodeModulePath
        Update-VsCodeTasksConfiguration
    } else {
        Write-Warning "VS Code integration module not found at $vsCodeModulePath"

        # Fallback implementation
        $vscodePath = Join-Path (Join-Path $PSScriptRoot ".." ".." "..") ".vscode"
        $tasksPath = Join-Path $vscodePath "tasks.json"

        if (-not (Test-Path $vscodePath)) {
            New-Item -Path $vscodePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path $tasksPath)) {
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
            } | ConvertTo-Json -Depth 4 | Out-File $tasksPath -Force

            Write-Verbose "Created VS Code tasks configuration"
        }
    }
}

# cSpell:ignore esac
# Note: 'esac' is a valid bash keyword - it's 'case' spelled backwards
# and is used to end case statements in shell scripts

function Process-ShellCommands {
    <#
    .SYNOPSIS
        Processes shell commands with proper handling of special keywords.
    .DESCRIPTION
        Ensures shell script syntax is properly handled, including bash-specific
        keywords like 'esac' (which is 'case' spelled backwards, used to end
        case statements in shell scripts).
    .PARAMETER Command
        The shell command to process.
    .EXAMPLE
        Process-ShellCommands -Command 'case "$1" in start) echo "Starting"; ;; stop) echo "Stopping"; ;; esac'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    # Import the shell processing module if available
    $shellModulePath = Join-Path (Split-Path $PSScriptRoot) "scripts\Process-ShellCommands.ps1"
    if (Test-Path $shellModulePath) {
        . $shellModulePath
        return Process-ShellCommand -Command $Command
    }

    # Fallback implementation
    # Handle shell commands, including those with case statements
    # In shell scripts, "case" blocks end with "esac" (case spelled backwards)
    if ($Command -match "case .* in") {
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
    'Process-ShellCommands'
)