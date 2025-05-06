# Test-ToolboxEnvironment.ps1
# This script tests the toolbox environment to ensure all tools are properly configured and functioning

param(
    [switch]$Detailed,
    [switch]$Fix
)

Write-Host "Testing toolbox environment..." -ForegroundColor Cyan

# Collect all toolbox scripts
$allTools = Get-ChildItem -Path "$PSScriptRoot\.." -Recurse -Filter "*.ps1" |
            Where-Object { -not $_.FullName.Contains("Update-") -and -not $_.Name -eq "Test-ToolboxEnvironment.ps1" }

$results = @{
    Passed = @()
    Failed = @()
    Skipped = @()
}

function Test-Tool {
    param(
        [string]$ToolPath,
        [string]$Category
    )

    $toolName = [System.IO.Path]::GetFileNameWithoutExtension($ToolPath)

    Write-Host "  Testing [$Category] $toolName..." -NoNewline

    # Check for common issues
    $content = Get-Content -Path $ToolPath -Raw

    $issues = @()

    # Check for absolute paths
    if ($content -match "c:\\Projects\\autogen" -or $content -match "C:\\Projects\\autogen") {
        $issues += "Contains hardcoded absolute paths"
    }

    # Check for invalid references
    if ($content -match "\\\$PSScriptRoot") {
        $issues += "Contains invalid \$PSScriptRoot references (extra backslash)"
    }

    # Check if script has proper header documentation
    if (-not ($content -match "^# .*\n# This script")) {
        $issues += "Missing proper header documentation"
    }

    # Check for proper parameter block
    if (-not ($content -match "param\s*\(" -and $content -match "\)")) {
        $issues += "Missing parameter block or has improper parameter block format"
    }

    # Check if file can be imported without errors (basic syntax check)
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
    }
    catch {
        $issues += "Parsing error: $_"
    }

    if ($issues.Count -eq 0) {
        Write-Host "PASSED" -ForegroundColor Green
        return @{
            Tool = $toolName
            Category = $Category
            Status = "Passed"
            Issues = $issues
        }
    }
    else {
        Write-Host "FAILED" -ForegroundColor Red
        if ($Detailed) {
            foreach ($issue in $issues) {
                Write-Host "    - $issue" -ForegroundColor Red
            }
        }

        # Fix issues if requested
        if ($Fix) {
            Write-Host "    Attempting to fix issues..." -ForegroundColor Yellow

            # Fix hardcoded paths
            if ($content -match "c:\\Projects\\autogen" -or $content -match "C:\\Projects\\autogen") {
                $content = $content -replace "c:\\Projects\\autogen", "`$PSScriptRoot\\..\\..\\."
                $content = $content -replace "C:\\Projects\\autogen", "`$PSScriptRoot\\..\\..\\."
            }

            # Fix invalid references
            if ($content -match "\\\$PSScriptRoot") {
                $content = $content -replace "\\\$PSScriptRoot", "`$PSScriptRoot"
            }

            # Add basic header documentation if missing
            if (-not ($content -match "^# .*\n# This script")) {
                $fileName = [System.IO.Path]::GetFileName($ToolPath)
                $toolBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ToolPath)
                $header = "# $toolBaseName`n# This script provides functionality for the $Category category in the AutoGen toolbox`n`n"
                $content = $header + $content
            }

            # Add parameter block if missing
            if (-not ($content -match "param\s*\(" -and $content -match "\)")) {
                $paramIdx = $content.IndexOf("Write-Host")
                if ($paramIdx -gt 0) {
                    $content = $content.Insert($paramIdx, "param()`n`n")
                }
            }

            # Write fixed content back to file
            Set-Content -Path $ToolPath -Value $content
            Write-Host "    Fixed issues in $toolName" -ForegroundColor Green
        }

        return @{
            Tool = $toolName
            Category = $Category
            Status = "Failed"
            Issues = $issues
        }
    }
}

function Test-DocumentationGeneration {
    Write-Host "  Testing documentation generation..." -NoNewline

    try {
        # Try to run the documentation generation script
        & "$PSScriptRoot\..\Generate-ToolboxDocs.ps1" -Format "markdown" | Out-Null

        if (Test-Path "$PSScriptRoot\..\documentation\toolbox-documentation.md") {
            Write-Host "PASSED" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "FAILED" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "FAILED" -ForegroundColor Red
        if ($Detailed) {
            Write-Host "    - Error: $_" -ForegroundColor Red
        }
        return $false
    }
}

function Test-VSCodeTaskIntegration {
    Write-Host "  Testing VS Code task integration..." -NoNewline

    $tasksJsonPath = "$PSScriptRoot\..\..\\.vscode\tasks.json"

    if (-not (Test-Path $tasksJsonPath)) {
        Write-Host "FAILED" -ForegroundColor Red
        if ($Detailed) {
            Write-Host "    - tasks.json file not found" -ForegroundColor Red
        }
        return $false
    }

    try {
        $tasksContent = Get-Content -Path $tasksJsonPath -Raw | ConvertFrom-Json

        $toolboxTasks = $tasksContent.tasks | Where-Object { $_.label -like "Toolbox:*" }

        if ($toolboxTasks.Count -gt 0) {
            # Check if paths use workspaceFolder variable
            $validPaths = $true

            foreach ($task in $toolboxTasks) {
                if ($task.args -and -not ($task.args | Where-Object { $_ -like "*`${workspaceFolder}*" })) {
                    $validPaths = $false
                    break
                }
            }

            if ($validPaths) {
                Write-Host "PASSED" -ForegroundColor Green
                return $true
            }
            else {
                Write-Host "FAILED" -ForegroundColor Red
                if ($Detailed) {
                    Write-Host "    - Some tasks don't use the `${workspaceFolder} variable" -ForegroundColor Red
                }
                return $false
            }
        }
        else {
            Write-Host "FAILED" -ForegroundColor Red
            if ($Detailed) {
                Write-Host "    - No toolbox tasks found in tasks.json" -ForegroundColor Red
            }
            return $false
        }
    }
    catch {
        Write-Host "FAILED" -ForegroundColor Red
        if ($Detailed) {
            Write-Host "    - Error parsing tasks.json: $_" -ForegroundColor Red
        }
        return $false
    }
}

function Test-ToolboxCatalog {
    Write-Host "  Testing toolbox catalog..." -NoNewline

    $catalogPath = "$PSScriptRoot\..\toolbox-catalog.xml"
    $schemaPath = "$PSScriptRoot\..\..\\.github\schemas\toolbox_catalog_schema.xsd"

    if (-not (Test-Path $catalogPath)) {
        Write-Host "FAILED" -ForegroundColor Red
        if ($Detailed) {
            Write-Host "    - Catalog file not found" -ForegroundColor Red
        }
        return $false
    }

    if (-not (Test-Path $schemaPath)) {
        Write-Host "FAILED" -ForegroundColor Red
        if ($Detailed) {
            Write-Host "    - Schema file not found" -ForegroundColor Red
        }
        return $false
    }

    try {
        [xml]$catalog = Get-Content -Path $catalogPath

        # Check if all tools are listed in the catalog
        $catalogTools = @()

        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            foreach ($tool in $category.tools.tool) {
                $catalogTools += $tool.name
            }
        }

        $missingTools = @()

        foreach ($tool in $allTools) {
            $toolName = $tool.Name
            if (-not ($catalogTools -contains $toolName)) {
                $missingTools += $toolName
            }
        }

        if ($missingTools.Count -eq 0) {
            Write-Host "PASSED" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "FAILED" -ForegroundColor Red
            if ($Detailed) {
                Write-Host "    - Missing tools in catalog: $($missingTools -join ", ")" -ForegroundColor Red
            }

            # Fix the catalog if requested
            if ($Fix) {
                Write-Host "    Updating catalog with missing tools..." -ForegroundColor Yellow
                # Implementation for fixing catalog would go here
                # This is a more complex operation that would need to be implemented
            }

            return $false
        }
    }
    catch {
        Write-Host "FAILED" -ForegroundColor Red
        if ($Detailed) {
            Write-Host "    - Error parsing catalog: $_" -ForegroundColor Red
        }
        return $false
    }
}

# Test each tool
Write-Host "Testing individual tools..." -ForegroundColor Cyan
foreach ($tool in $allTools) {
    $category = $tool.Directory.Name
    $result = Test-Tool -ToolPath $tool.FullName -Category $category

    switch ($result.Status) {
        "Passed" { $results.Passed += $result }
        "Failed" { $results.Failed += $result }
        "Skipped" { $results.Skipped += $result }
    }
}

# Test documentation generation
Write-Host "`nTesting integrations..." -ForegroundColor Cyan
$docGenResult = Test-DocumentationGeneration
$vscodeResult = Test-VSCodeTaskIntegration
$catalogResult = Test-ToolboxCatalog

# Display summary
Write-Host "`nToolbox Environment Test Results:" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Cyan
Write-Host "Individual Tools: $($results.Passed.Count) passed, $($results.Failed.Count) failed, $($results.Skipped.Count) skipped" -ForegroundColor $(if ($results.Failed.Count -eq 0) { "Green" } else { "Red" })
Write-Host "Documentation Generation: $(if ($docGenResult) { "PASSED" } else { "FAILED" })" -ForegroundColor $(if ($docGenResult) { "Green" } else { "Red" })
Write-Host "VS Code Task Integration: $(if ($vscodeResult) { "PASSED" } else { "FAILED" })" -ForegroundColor $(if ($vscodeResult) { "Green" } else { "Red" })
Write-Host "Toolbox Catalog: $(if ($catalogResult) { "PASSED" } else { "FAILED" })" -ForegroundColor $(if ($catalogResult) { "Green" } else { "Red" })

# Display detailed failure information if requested
if ($Detailed -and $results.Failed.Count -gt 0) {
    Write-Host "`nFailed Tools:" -ForegroundColor Red
    $results.Failed | ForEach-Object {
        Write-Host "  [$($_.Category)] $($_.Tool)" -ForegroundColor Red
        foreach ($issue in $_.Issues) {
            Write-Host "    - $issue" -ForegroundColor Red
        }
    }
}

# Return status code for automation
if ($results.Failed.Count -eq 0 -and $docGenResult -and $vscodeResult -and $catalogResult) {
    Write-Host "`nOverall Status: PASSED" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`nOverall Status: FAILED" -ForegroundColor Red
    Write-Host "Run with -Fix parameter to attempt automatic fixes" -ForegroundColor Yellow
    exit 1
}
