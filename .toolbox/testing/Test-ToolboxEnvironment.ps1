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

function Test-DirTagFiles {
    Write-Host "  Testing DIR.TAG files..." -NoNewline

    $directories = Get-ChildItem -Path "$PSScriptRoot\.." -Directory | Where-Object { $_.Name -ne "documentation" }
    $missingDirTags = @()

    foreach ($dir in $directories) {
        $dirTagPath = Join-Path $dir.FullName "DIR.TAG"
        if (-not (Test-Path $dirTagPath)) {
            $missingDirTags += $dir.FullName
        }
    }

    if ($missingDirTags.Count -eq 0) {
        Write-Host "PASSED" -ForegroundColor Green
        return $true
    } else {
        Write-Host "FAILED" -ForegroundColor Red

        if ($Detailed) {
            Write-Host "    Missing DIR.TAG files in directories:" -ForegroundColor Red
            foreach ($dir in $missingDirTags) {
                Write-Host "      - $dir" -ForegroundColor Red
            }
        }

        if ($Fix) {
            foreach ($dir in $missingDirTags) {
                $dirName = Split-Path $dir -Leaf
                $dirTagContent = "#INDEX: .toolbox/$dirName`n#TODO:`n  - Add additional tools to this category NOT_STARTED`n`nstatus: PARTIALLY_COMPLETE`nupdated: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")`ndescription: |`n  Tools for $dirName-related operations.`n"
                Set-Content -Path (Join-Path $dir "DIR.TAG") -Value $dirTagContent
                Write-Host "      Created DIR.TAG for $dirName" -ForegroundColor Green
            }
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
        Write-Host "    Toolbox catalog not found at: $catalogPath" -ForegroundColor Red
        return $false
    }

    try {
        $catalog = [xml](Get-Content $catalogPath)

        # Validate against schema if available
        if (Test-Path $schemaPath) {
            $schema = New-Object System.Xml.Schema.XmlSchemaSet
            $schema.Add($null, $schemaPath) | Out-Null
            $catalog.Schemas = $schema

            $errorOccurred = $false
            $catalog.Validate({
                param($sender, $e)
                Write-Host "    XML Validation Error: $($e.Message)" -ForegroundColor Red
                $errorOccurred = $true
            })

            if ($errorOccurred) {
                Write-Host "FAILED" -ForegroundColor Red
                Write-Host "    Catalog validation against schema failed" -ForegroundColor Red
                return $false
            }
        }

        # Check for basic structure
        if ($null -eq $catalog.toolbox_catalog) {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "    Invalid catalog format: missing toolbox_catalog root element" -ForegroundColor Red
            return $false
        }

        if ($null -eq $catalog.toolbox_catalog.categories) {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "    Invalid catalog format: missing categories element" -ForegroundColor Red
            return $false
        }

        # Check for categories
        $categories = $catalog.toolbox_catalog.categories.category
        if ($null -eq $categories -or $categories.Count -eq 0) {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "    No categories found in the catalog" -ForegroundColor Red
            return $false
        }

        # Validate tools
        $toolPaths = @()
        $duplicateToolPaths = @()
        $missingToolFiles = @()
        $duplicateToolIds = @()
        $toolIds = @()
        $sequenceIssues = @()

        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $categoryName = $category.name
            $tools = $category.SelectNodes("tools/tool")

            foreach ($tool in $tools) {
                # Check ID
                $toolId = $tool.SelectSingleNode("id")?.InnerText ?? ""
                if ($toolId -eq "") {
                    Write-Host "FAILED" -ForegroundColor Red
                    Write-Host "    Tool in category '$categoryName' is missing an ID" -ForegroundColor Red
                    return $false
                }

                if ($toolIds -contains $toolId) {
                    $duplicateToolIds += $toolId
                } else {
                    $toolIds += $toolId
                }

                # Check path
                $toolPath = $tool.SelectSingleNode("path")?.InnerText ?? ""
                if ($toolPath -eq "") {
                    Write-Host "FAILED" -ForegroundColor Red
                    Write-Host "    Tool with ID '$toolId' is missing a path" -ForegroundColor Red
                    return $false
                }

                $fullToolPath = "$PSScriptRoot\..\..\$toolPath"
                if (-not (Test-Path $fullToolPath)) {
                    $missingToolFiles += $toolPath
                }

                if ($toolPaths -contains $toolPath) {
                    $duplicateToolPaths += $toolPath
                } else {
                    $toolPaths += $toolPath
                }

                # Check sequence
                $sequence = $tool.SelectSingleNode("sequence")?.InnerText ?? ""
                if ($sequence -eq "" -or -not [int]::TryParse($sequence, [ref]$null)) {
                    $sequenceIssues += "Tool with ID '$toolId' has invalid sequence: '$sequence'"
                }

                # Check dependencies
                $dependencies = $tool.SelectNodes("dependencies/dependency")
                foreach ($dependency in $dependencies) {
                    $dependencyId = $dependency.InnerText
                    if (-not ($toolIds -contains $dependencyId) -and -not ($toolId -eq $dependencyId)) {
                        $sequenceIssues += "Tool with ID '$toolId' has dependency on non-existent tool ID: '$dependencyId'"
                    }
                }
            }
        }

        $hasIssues = $false

        if ($duplicateToolPaths.Count -gt 0) {
            $hasIssues = $true
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "    Found duplicate tool paths in catalog:" -ForegroundColor Red
            foreach ($path in $duplicateToolPaths) {
                Write-Host "      - $path" -ForegroundColor Red
            }
            return $false
        }

        if ($missingToolFiles.Count -gt 0) {
            $hasIssues = $true
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "    Found references to non-existent tool files:" -ForegroundColor Red
            foreach ($path in $missingToolFiles) {
                Write-Host "      - $path" -ForegroundColor Red
            }
            return $false
        }

        if ($duplicateToolIds.Count -gt 0) {
            $hasIssues = $true
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "    Found duplicate tool IDs in catalog:" -ForegroundColor Red
            foreach ($id in $duplicateToolIds) {
                Write-Host "      - $id" -ForegroundColor Red
            }
            return $false
        }

        if ($sequenceIssues.Count -gt 0) {
            $hasIssues = $true
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "    Found sequence or dependency issues:" -ForegroundColor Red
            foreach ($issue in $sequenceIssues) {
                Write-Host "      - $issue" -ForegroundColor Red
            }
            return $false
        }

        # Check that all PS1 files in the toolbox are included in the catalog
        $allPs1Files = Get-ChildItem -Path "$PSScriptRoot\.." -Recurse -Filter "*.ps1" |
                       Where-Object {
                          -not $_.FullName.Contains("Update-") -and
                          -not $_.Name -eq "Test-ToolboxEnvironment.ps1" -and
                          -not $_.Name -eq "Generate-ToolboxDocs.ps1" -and
                          -not $_.Name -eq "Register-Tool.ps1"
                       }

        $missingFromCatalog = @()
        foreach ($ps1File in $allPs1Files) {
            $relativePath = $ps1File.FullName.Replace((Get-Item "$PSScriptRoot\..\..\").FullName, "").TrimStart("\").Replace("\", "/")
            if (-not ($toolPaths -contains $relativePath)) {
                $missingFromCatalog += $relativePath
            }
        }

        if ($missingFromCatalog.Count -gt 0) {
            $hasIssues = $true
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "    Found toolbox scripts not included in the catalog:" -ForegroundColor Red
            foreach ($path in $missingFromCatalog) {
                Write-Host "      - $path" -ForegroundColor Red
            }

            if ($Fix) {
                Write-Host "    Attempting to fix missing catalog entries..." -ForegroundColor Yellow
                foreach ($path in $missingFromCatalog) {
                    $scriptName = Split-Path $path -Leaf
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($scriptName)
                    $categoryPath = Split-Path $path -Parent
                    $categoryName = Split-Path $categoryPath -Leaf

                    # Find the category in the catalog
                    $categoryElement = $catalog.SelectSingleNode("//category[name='$categoryName']")
                    if ($null -eq $categoryElement) {
                        # Create new category if it doesn't exist
                        $categoryId = [guid]::NewGuid().ToString()
                        $newCategory = $catalog.CreateElement("category")
                        $newCategory.SetAttribute("id", $categoryId)

                        $nameElement = $catalog.CreateElement("name")
                        $nameElement.InnerText = $categoryName
                        $newCategory.AppendChild($nameElement)

                        $descElement = $catalog.CreateElement("description")
                        $descElement.InnerText = "Tools for $categoryName-related operations"
                        $newCategory.AppendChild($descElement)

                        $toolsElement = $catalog.CreateElement("tools")
                        $newCategory.AppendChild($toolsElement)

                        $catalog.toolbox_catalog.categories.AppendChild($newCategory) | Out-Null
                        Write-Host "      Added missing category '$categoryName' to catalog" -ForegroundColor Green
                        $categoryElement = $newCategory
                    }

                    # Add the tool to the category
                    $toolElement = $catalog.CreateElement("tool")

                    $idElement = $catalog.CreateElement("id")
                    $idElement.InnerText = [guid]::NewGuid().ToString()
                    $toolElement.AppendChild($idElement) | Out-Null

                    $nameElement = $catalog.CreateElement("name")
                    $nameElement.InnerText = $baseName
                    $toolElement.AppendChild($nameElement) | Out-Null

                    $pathElement = $catalog.CreateElement("path")
                    $pathElement.InnerText = $relativePath
                    $toolElement.AppendChild($pathElement) | Out-Null

                    $sequenceElement = $catalog.CreateElement("sequence")
                    $sequenceElement.InnerText = ($category.tools.tool.Count + 1).ToString()
                    $toolElement.AppendChild($sequenceElement) | Out-Null

                    $dependenciesElement = $catalog.CreateElement("dependencies")
                    $toolElement.AppendChild($dependenciesElement) | Out-Null

                    # Add default TODO dependency
                    $todoDependency = $catalog.CreateElement("dependency")
                    $todoDependency.InnerText = "TODO"
                    $dependenciesElement.AppendChild($todoDependency) | Out-Null

                    $category.tools.AppendChild($toolElement) | Out-Null
                    Write-Host "      Added missing tool '$baseName' to category '$categoryName' in catalog" -ForegroundColor Green
                }

                # Save the updated catalog
                $catalog.Save($catalogPath)
                Write-Host "    Updated catalog saved" -ForegroundColor Green
            }
        }

        return -not $hasIssues
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
$dirTagResult = Test-DirTagFiles

# Display summary
Write-Host "`nToolbox Environment Test Results:" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Cyan
Write-Host "Individual Tools: $($results.Passed.Count) passed, $($results.Failed.Count) failed, $($results.Skipped.Count) skipped" -ForegroundColor $(if ($results.Failed.Count -eq 0) { "Green" } else { "Red" })
Write-Host "Documentation Generation: $(if ($docGenResult) { "PASSED" } else { "FAILED" })" -ForegroundColor $(if ($docGenResult) { "Green" } else { "Red" })
Write-Host "VS Code Task Integration: $(if ($vscodeResult) { "PASSED" } else { "FAILED" })" -ForegroundColor $(if ($vscodeResult) { "Green" } else { "Red" })
Write-Host "Toolbox Catalog: $(if ($catalogResult) { "PASSED" } else { "FAILED" })" -ForegroundColor $(if ($catalogResult) { "Green" } else { "Red" })
Write-Host "DIR.TAG Files: $(if ($dirTagResult) { "PASSED" } else { "FAILED" })" -ForegroundColor $(if ($dirTagResult) { "Green" } else { "Red" })

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
if ($results.Failed.Count -eq 0 -and $docGenResult -and $vscodeResult -and $catalogResult -and $dirTagResult) {
    Write-Host "`nOverall Status: PASSED" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`nOverall Status: FAILED" -ForegroundColor Red
    Write-Host "Run with -Fix parameter to attempt automatic fixes" -ForegroundColor Yellow
    exit 1
}
