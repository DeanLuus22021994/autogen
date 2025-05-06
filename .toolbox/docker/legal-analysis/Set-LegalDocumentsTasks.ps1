# Set-LegalDocumentsTasks.ps1
<#
.SYNOPSIS
    Sets up VS Code tasks for legal document analysis.

.DESCRIPTION
    Creates or updates VS Code tasks for processing legal documents.

.PARAMETER Force
    If specified, overwrites existing tasks.

.EXAMPLE
    .\Set-LegalDocumentsTasks.ps1
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force
)

# Locate the .vscode folder in the workspace
$workspaceRoot = $PWD
$vscodePath = Join-Path $workspaceRoot ".vscode"
$tasksPath = Join-Path $vscodePath "tasks.json"

# Create .vscode directory if it doesn't exist
if (-not (Test-Path $vscodePath)) {
    New-Item -ItemType Directory -Path $vscodePath -Force | Out-Null
}

# Define the legal document tasks
$legalTasks = @(
    @{
        label = "Legal Analysis: Process Document"
        type = "shell"
        command = "pwsh"
        args = @(
            "-File",
            "${workspaceFolder}\.toolbox\docker\legal-analysis\Process-LegalDocuments.ps1",
            "-InputFile",
            "`${input:legalDocumentPath}"
        )
        group = "test"
    },
    @{
        label = "Legal Analysis: Watch Folder"
        type = "shell"
        command = "pwsh"
        args = @(
            "-File",
            "${workspaceFolder}\.toolbox\docker\legal-analysis\Process-LegalDocuments.ps1",
            "-WatchFolder",
            "`${input:legalFolderPath}"
        )
        group = "test"
        isBackground = $true
        problemMatcher = @()
    },
    @{
        label = "Legal Analysis: Start Docker Stack"
        type = "shell"
        command = "pwsh"
        args = @(
            "-File",
            "${workspaceFolder}\.toolbox\docker\legal-analysis\Start-LegalAnalysisSystem.ps1"
        )
        group = "test"
    },
    @{
        label = "Legal Analysis: Generate Test Documents"
        type = "shell"
        command = "pwsh"
        args = @(
            "-File",
            "${workspaceFolder}\.toolbox\docker\legal-analysis\Generate-TestDocuments.ps1",
            "-Count",
            "3"
        )
        group = "test"
    }
)

# Define the inputs
$legalInputs = @(
    @{
        id = "legalDocumentPath"
        description = "Path to the legal document to process"
        default = ""
        type = "promptString"
    },
    @{
        id = "legalFolderPath"
        description = "Path to the folder to watch for legal documents"
        default = "./incoming-documents"
        type = "promptString"
    }
)

# Read existing tasks.json file if it exists
if (Test-Path $tasksPath) {
    try {
        $tasksContent = Get-Content -Path $tasksPath -Raw | ConvertFrom-Json

        # Check if version exists
        if (-not $tasksContent.version) {
            $tasksContent | Add-Member -MemberType NoteProperty -Name "version" -Value "2.0.0"
        }

        # Check if tasks exists
        if (-not $tasksContent.tasks) {
            $tasksContent | Add-Member -MemberType NoteProperty -Name "tasks" -Value @()
        }

        # Check if inputs exists
        if (-not $tasksContent.inputs) {
            $tasksContent | Add-Member -MemberType NoteProperty -Name "inputs" -Value @()
        }

        # Add or update tasks
        foreach ($task in $legalTasks) {
            $existingTask = $tasksContent.tasks | Where-Object { $_.label -eq $task.label }
            if ($existingTask) {
                if ($Force) {
                    # Replace task
                    $index = [array]::IndexOf($tasksContent.tasks, $existingTask)
                    $tasksContent.tasks[$index] = $task
                    Write-Host "Updated task: $($task.label)" -ForegroundColor Yellow
                } else {
                    Write-Host "Task already exists: $($task.label)" -ForegroundColor Cyan
                }
            } else {
                # Add new task
                $tasksContent.tasks += $task
                Write-Host "Added task: $($task.label)" -ForegroundColor Green
            }
        }

        # Add or update inputs
        foreach ($input in $legalInputs) {
            $existingInput = $tasksContent.inputs | Where-Object { $_.id -eq $input.id }
            if ($existingInput) {
                if ($Force) {
                    # Replace input
                    $index = [array]::IndexOf($tasksContent.inputs, $existingInput)
                    $tasksContent.inputs[$index] = $input
                    Write-Host "Updated input: $($input.id)" -ForegroundColor Yellow
                } else {
                    Write-Host "Input already exists: $($input.id)" -ForegroundColor Cyan
                }
            } else {
                # Add new input
                $tasksContent.inputs += $input
                Write-Host "Added input: $($input.id)" -ForegroundColor Green
            }
        }

        # Write updated tasks back to file
        $tasksContent | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksPath
    } catch {
        Write-Warning "Error updating tasks.json: $_"
        Write-Host "Creating new tasks.json file..." -ForegroundColor Yellow

        # Create new tasks.json file
        @{
            version = "2.0.0"
            tasks = $legalTasks
            inputs = $legalInputs
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksPath
    }
} else {
    # Create new tasks.json file
    @{
        version = "2.0.0"
        tasks = $legalTasks
        inputs = $legalInputs
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksPath

    Write-Host "Created new tasks.json file with legal document analysis tasks" -ForegroundColor Green
}

Write-Host "Done! Legal document analysis tasks have been configured in VS Code." -ForegroundColor Green
Write-Host "You can run these tasks from the Terminal > Run Task... menu in VS Code." -ForegroundColor Green
