# .github/linting/scripts/Update-VsCodeConfig.ps1
# VS Code integration utilities for markdown linting

<#
.SYNOPSIS
    Provides utilities for integrating markdown linting with VS Code.
.DESCRIPTION
    Functions to update and manage VS Code settings and tasks related to markdown linting.
#>

function Update-VsCodeTasksConfiguration {
    <#
    .SYNOPSIS
        Updates VS Code tasks configuration for markdown linting.
    .DESCRIPTION
        Creates or updates VS Code tasks.json file with markdown linting tasks.
    .PARAMETER Force
        If specified, overwrites existing tasks without prompting.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force
    )

    # Get repository root directory
    $repoRoot = $null
    try {
        $repoRoot = git rev-parse --show-toplevel 2>$null
    }
    catch {
        $repoRoot = $null
    }

    # Use current location if not in a git repository
    $basePath = $repoRoot ?? $PWD.Path

    # VS Code paths
    $vscodePath = Join-Path $basePath ".vscode"
    $tasksPath = Join-Path $vscodePath "tasks.json"

    # Ensure .vscode directory exists
    if (-not (Test-Path $vscodePath)) {
        New-Item -Path $vscodePath -ItemType Directory -Force | Out-Null
        Write-Verbose "Created .vscode directory at $vscodePath"
    }

    # Define markdown linting tasks
    $markdownTasks = @(
        @{
            label = "Lint Markdown"
            type = "shell"
            command = "npx markdownlint-cli2 '**/*.md'"
            problemMatcher = @()
            group = @{
                kind = "build"
                isDefault = $false
            }
        },
        @{
            label = "Fix Markdown Issues"
            type = "shell"
            command = "npx markdownlint-cli2 --fix '**/*.md'"
            problemMatcher = @()
            group = @{
                kind = "build"
                isDefault = $false
            }
        },
        @{
            label = "Generate Markdown Report"
            type = "shell"
            command = "pwsh -File .github/linting/scripts/Generate-MarkdownReport.ps1"
            problemMatcher = @()
            group = @{
                kind = "test"
                isDefault = $false
            }
        }
    )

    # Update existing tasks file or create new one
    if (Test-Path $tasksPath) {
        try {
            $tasksContent = Get-Content -Path $tasksPath -Raw | ConvertFrom-Json

            # Check if tasks property exists
            if (-not $tasksContent.tasks) {
                $tasksContent | Add-Member -MemberType NoteProperty -Name "tasks" -Value @()
            }

            # Process each markdown task
            foreach ($task in $markdownTasks) {
                $existingTask = $tasksContent.tasks | Where-Object { $_.label -eq $task.label }

                if ($existingTask) {
                    # Task exists - update if forced
                    if ($Force) {
                        $taskIndex = [array]::IndexOf($tasksContent.tasks, $existingTask)
                        $tasksContent.tasks[$taskIndex] = $task
                        Write-Verbose "Updated existing task: $($task.label)"
                    }
                    else {
                        Write-Verbose "Task already exists (use -Force to update): $($task.label)"
                    }
                }
                else {
                    # Task doesn't exist - add it
                    $tasksContent.tasks += $task
                    Write-Verbose "Added new task: $($task.label)"
                }
            }

            # Save updated tasks
            $tasksContent | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksPath -Force
            Write-Verbose "Updated VS Code tasks at $tasksPath"
        }
        catch {
            Write-Warning "Error updating VS Code tasks: $_"

            # Create new tasks file if error occurs
            @{
                version = "2.0.0"
                tasks = $markdownTasks
            } | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksPath -Force

            Write-Verbose "Created new VS Code tasks at $tasksPath due to error"
        }
    }
    else {
        # Create new tasks file
        @{
            version = "2.0.0"
            tasks = $markdownTasks
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksPath -Force

        Write-Verbose "Created new VS Code tasks at $tasksPath"
    }
}

function Update-VsCodeSettings {
    <#
    .SYNOPSIS
        Updates VS Code settings for markdown linting.
    .DESCRIPTION
        Creates or updates VS Code settings.json file with markdown linting configuration.
    .PARAMETER Force
        If specified, overwrites existing settings without prompting.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force
    )

    # Get repository root directory
    $repoRoot = $null
    try {
        $repoRoot = git rev-parse --show-toplevel 2>$null
    }
    catch {
        $repoRoot = $null
    }

    # Use current location if not in a git repository
    $basePath = $repoRoot ?? $PWD.Path

    # VS Code paths
    $vscodePath = Join-Path $basePath ".vscode"
    $settingsPath = Join-Path $vscodePath "settings.json"

    # Ensure .vscode directory exists
    if (-not (Test-Path $vscodePath)) {
        New-Item -Path $vscodePath -ItemType Directory -Force | Out-Null
        Write-Verbose "Created .vscode directory at $vscodePath"
    }

    # Define markdown linting settings
    $markdownSettings = @{
        "markdownlint.config" = @{
            extends = ".github/linting/.markdownlint.json"
        }
        "editor.formatOnSave" = $true
        "cSpell.words" = @(
            "markdownlint",
            "markdownlintrc",
            "markdownlintignore",
            "esac"
        )
    }

    # Update existing settings file or create new one
    if (Test-Path $settingsPath) {
        try {
            $settingsContent = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json -AsHashtable

            # Update markdown linting settings
            foreach ($key in $markdownSettings.Keys) {
                if ($settingsContent.ContainsKey($key)) {
                    # Setting exists - update if forced
                    if ($Force) {
                        $settingsContent[$key] = $markdownSettings[$key]
                        Write-Verbose "Updated existing setting: $key"
                    }
                    else {
                        Write-Verbose "Setting already exists (use -Force to update): $key"
                    }
                }
                else {
                    # Setting doesn't exist - add it
                    $settingsContent[$key] = $markdownSettings[$key]
                    Write-Verbose "Added new setting: $key"
                }
            }

            # Special handling for cSpell.words array
            if ($settingsContent.ContainsKey("cSpell.words") -and $settingsContent["cSpell.words"] -is [Array]) {
                # Ensure all our words are in the array
                $existingWords = [System.Collections.ArrayList]::new($settingsContent["cSpell.words"])
                $newWords = @()

                foreach ($word in $markdownSettings["cSpell.words"]) {
                    if ($word -notin $existingWords) {
                        $existingWords.Add($word)
                        $newWords += $word
                    }
                }

                if ($newWords.Count -gt 0) {
                    $settingsContent["cSpell.words"] = $existingWords.ToArray()
                    Write-Verbose "Added $($newWords.Count) new words to cSpell.words"
                }
            }

            # Save updated settings
            $settingsContent | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Force
            Write-Verbose "Updated VS Code settings at $settingsPath"
        }
        catch {
            Write-Warning "Error updating VS Code settings: $_"

            # Create new settings file if error occurs
            $markdownSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Force
            Write-Verbose "Created new VS Code settings at $settingsPath due to error"
        }
    }
    else {
        # Create new settings file
        $markdownSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Force
        Write-Verbose "Created new VS Code settings at $settingsPath"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Update-VsCodeTasksConfiguration',
    'Update-VsCodeSettings'
)