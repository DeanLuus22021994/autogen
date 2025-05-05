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
                    problemMatcher = []
                    group = @{
                        kind = "build"
                        isDefault = $false
                    }
                }
            )
        } | ConvertTo-Json -Depth 4 | Out-File $tasksPath -Force

        Write-Verbose "Created VS Code tasks configuration"
    } else {
        # Update existing tasks file
        try {
            $tasksContent = Get-Content $tasksPath -Raw | ConvertFrom-Json

            # Check if our task already exists
            $markdownTask = $tasksContent.tasks | Where-Object { $_.label -eq "Lint Markdown" }

            if (-not $markdownTask) {
                # Add our task
                $newTask = @{
                    label = "Lint Markdown"
                    type = "shell"
                    command = "npx markdownlint-cli2 '**/*.md'"
                    problemMatcher = @()
                    group = @{
                        kind = "build"
                        isDefault = $false
                    }
                }

                $tasksContent.tasks += $newTask
                $tasksContent | ConvertTo-Json -Depth 4 | Out-File $tasksPath -Force

                Write-Verbose "Added Markdown linting task to VS Code configuration"
            } else {
                Write-Verbose "Markdown linting task already exists in VS Code configuration"
            }
        } catch {
            Write-Warning "Could not update VS Code tasks: $_"
        }
    }
}

# Fix for the "esac" spelling issue in the original file
# This is a placeholder - in the original file "esac" is likely part
# of a bash/shell case statement end marker and should be kept as is
function Process-ShellCommands {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

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