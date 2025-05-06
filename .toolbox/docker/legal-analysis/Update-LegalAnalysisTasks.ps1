# Update-LegalAnalysisTasks.ps1
<#
.SYNOPSIS
    Updates VS Code tasks configuration for legal document analysis.

.DESCRIPTION
    Creates or updates VS Code tasks.json file with legal document analysis tasks.

.PARAMETER Force
    If specified, overwrites existing tasks without prompting.

.EXAMPLE
    .\Update-LegalAnalysisTasks.ps1

.EXAMPLE
    .\Update-LegalAnalysisTasks.ps1 -Force
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

# Define legal document analysis tasks
$legalAnalysisTasks = @(
    @{
        label = "Process Legal Document"
        type = "shell"
        command = "pwsh"
        args = @(
            "-File",
            "`${workspaceFolder}\\.toolbox\\docker\\legal-analysis\\Process-LegalDocuments.ps1",
            "-InputFile",
            "`${input:legalDocumentPath}",
            "-ModelType",
            "`${input:legalModelType}",
            "-QuantizationLevel",
            "`${input:quantizationLevel}"
        )
        group = @{
            kind = "build"
            isDefault = $false
        }
    },
    @{
        label = "Watch Folder for Legal Documents"
        type = "shell"
        command = "pwsh"
        args = @(
            "-File",
            "`${workspaceFolder}\\.toolbox\\docker\\legal-analysis\\Process-LegalDocuments.ps1",
            "-WatchFolder",
            "`${input:watchFolderPath}",
            "-ModelType",
            "`${input:legalModelType}",
            "-QuantizationLevel",
            "`${input:quantizationLevel}"
        )
        group = @{
            kind = "build"
            isDefault = $false
        }
        isBackground = $true
        problemMatcher = @()
    },
    @{
        label = "Start Legal Analysis Docker Stack"
        type = "shell"
        command = "docker"
        args = @(
            "compose",
            "-f",
            "`${workspaceFolder}\\.toolbox\\docker\\legal-analysis\\docker-compose.yml",
            "up",
            "-d"
        )
        group = @{
            kind = "build"
            isDefault = $false
        }
    },
    @{
        label = "Stop Legal Analysis Docker Stack"
        type = "shell"
        command = "docker"
        args = @(
            "compose",
            "-f",
            "`${workspaceFolder}\\.toolbox\\docker\\legal-analysis\\docker-compose.yml",
            "down"
        )
        group = "build"
    }
)

# Define inputs for the tasks
$legalAnalysisInputs = @(
    @{
        id = "legalDocumentPath"
        description = "Path to the legal document to process"
        default = ""
        type = "promptString"
    },
    @{
        id = "watchFolderPath"
        description = "Path to folder to watch for legal documents"
        default = "./incoming-documents"
        type = "promptString"
    },
    @{
        id = "legalModelType"
        description = "AI model to use for analysis"
        default = "ai/mistral-nemo"
        options = @(
            @{
                label = "Mistral NeMo (optimized for NVIDIA GPUs)"
                value = "ai/mistral-nemo"
            },
            @{
                label = "Mistral (standard)"
                value = "ai/mistral"
            },
            @{
                label = "Llama 3"
                value = "ai/llama3"
            }
        )
        type = "pickString"
    },
    @{
        id = "quantizationLevel"
        description = "Quantization level for the model"
        default = "int8"
        options = @(
            @{
                label = "INT8 (good balance of speed and quality)"
                value = "int8"
            },
            @{
                label = "INT4 (fastest, lower quality)"
                value = "int4"
            },
            @{
                label = "None (highest quality, slowest)"
                value = "none"
            }
        )
        type = "pickString"
    }
)

# Update existing tasks file or create new one
if (Test-Path $tasksPath) {
    try {
        $tasksContent = Get-Content -Path $tasksPath -Raw | ConvertFrom-Json

        # Check if version property exists, if not add it
        if (-not $tasksContent.version) {
            $tasksContent | Add-Member -MemberType NoteProperty -Name "version" -Value "2.0.0"
        }

        # Check if tasks property exists
        if (-not $tasksContent.tasks) {
            $tasksContent | Add-Member -MemberType NoteProperty -Name "tasks" -Value @()
        }

        # Check if inputs property exists
        if (-not $tasksContent.inputs) {
            $tasksContent | Add-Member -MemberType NoteProperty -Name "inputs" -Value @()
        }

        # Process each legal analysis task
        foreach ($task in $legalAnalysisTasks) {
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

        # Process each input
        foreach ($input in $legalAnalysisInputs) {
            $existingInput = $tasksContent.inputs | Where-Object { $_.id -eq $input.id }

            if ($existingInput) {
                # Input exists - update if forced
                if ($Force) {
                    $inputIndex = [array]::IndexOf($tasksContent.inputs, $existingInput)
                    $tasksContent.inputs[$inputIndex] = $input
                    Write-Verbose "Updated existing input: $($input.id)"
                }
                else {
                    Write-Verbose "Input already exists (use -Force to update): $($input.id)"
                }
            }
            else {
                # Input doesn't exist - add it
                $tasksContent.inputs += $input
                Write-Verbose "Added new input: $($input.id)"
            }
        }

        # Save updated tasks
        $tasksContent | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksPath -Force
        Write-Host "Updated VS Code tasks at $tasksPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Error updating VS Code tasks: $_"

        # Create new tasks file if error occurs
        @{
            version = "2.0.0"
            tasks = $legalAnalysisTasks
            inputs = $legalAnalysisInputs
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksPath -Force

        Write-Host "Created new VS Code tasks at $tasksPath due to error" -ForegroundColor Yellow
    }
}
else {
    # Create new tasks file
    @{
        version = "2.0.0"
        tasks = $legalAnalysisTasks
        inputs = $legalAnalysisInputs
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksPath -Force

    Write-Host "Created new VS Code tasks at $tasksPath" -ForegroundColor Green
}
