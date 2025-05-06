<#
.SYNOPSIS
    Exports documentation for the AutoGen toolbox.
.DESCRIPTION
    Reads the toolbox-catalog.xml file and exports documentation in various formats.
    Supports ordered presentation of tools based on their sequence numbers.
.PARAMETER Format
    The format of the documentation to generate: 'markdown', 'html', or 'text'.
.PARAMETER OutputPath
    The directory where the documentation will be saved. Defaults to '.toolbox/documentation'.
.PARAMETER IncludeDependencies
    If specified, includes tool dependency information in the documentation.
.PARAMETER GroupByCategory
    If specified, groups tools by category in the documentation.
.EXAMPLE
    .\Generate-ToolboxDocs.ps1 -Format "markdown"
.EXAMPLE
    .\Generate-ToolboxDocs.ps1 -Format "html" -IncludeDependencies
#>

param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("markdown", "html", "text")]
    [string]$Format = "markdown",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "documentation",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeDependencies,

    [Parameter(Mandatory = $false)]
    [switch]$GroupByCategory = $false
)

Write-Host "Exporting toolbox documentation in $Format format..." -ForegroundColor Cyan

# Load the toolbox catalog
$catalogPath = "$PSScriptRoot\toolbox-catalog.xml"
if (-not (Test-Path $catalogPath)) {
    Write-Error "Toolbox catalog not found at: $catalogPath"
    exit 1
}

$catalog = [xml](Get-Content $catalogPath)

# Create the output directory if it doesn't exist
$OutputPath = Join-Path $PSScriptRoot $OutputPath
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory | Out-Null
}

# Get dependency names from IDs
function Get-DependencyNames {
    param (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$ToolElement
    )

    $dependencyIds = @()
    $dependenciesElement = $ToolElement.SelectSingleNode("dependencies")
    if ($dependenciesElement -ne $null) {
        $dependencyElements = $dependenciesElement.SelectNodes("dependency")
        foreach ($dependencyElement in $dependencyElements) {
            $dependencyIds += $dependencyElement.InnerText
        }
    }

    $dependencyNames = @()
    foreach ($dependencyId in $dependencyIds) {
        $dependencyTool = $catalog.SelectSingleNode("//tool[id='$dependencyId']")
        if ($dependencyTool -ne $null) {
            $dependencyNames += $dependencyTool.SelectSingleNode("name").InnerText
        }
    }

    return $dependencyNames
}

# Generate markdown documentation
function Export-MarkdownDocumentation {
    $sb = [System.Text.StringBuilder]::new()
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $null = $sb.AppendLine("# AutoGen Toolbox Documentation")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("> Version: $($catalog.toolbox_catalog.metadata.version)")
    $null = $sb.AppendLine("> Generated: $timestamp")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("$($catalog.toolbox_catalog.metadata.description)")
    $null = $sb.AppendLine("")

    if ($GroupByCategory) {
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $categoryName = $category.name
            $categoryDescription = $category.description

            $null = $sb.AppendLine("## $categoryName")
            $null = $sb.AppendLine("")
            $null = $sb.AppendLine("$categoryDescription")
            $null = $sb.AppendLine("")
            $null = $sb.AppendLine("| Tool | Description | Tags |")
            $null = $sb.AppendLine("|------|-------------|------|")

            $tools = $category.SelectNodes("tools/tool") | Sort-Object { [int]$_.SelectSingleNode("sequence").InnerText }

            foreach ($tool in $tools) {
                $toolName = $tool.SelectSingleNode("name").InnerText
                $toolPath = $tool.SelectSingleNode("path").InnerText
                $toolDescription = $tool.SelectSingleNode("description").InnerText
                $toolTags = $tool.SelectSingleNode("tags")?.InnerText ?? ""

                $null = $sb.AppendLine("| [$toolName]($toolPath) | $toolDescription | $toolTags |")

                if ($IncludeDependencies) {
                    $dependencies = Get-DependencyNames -ToolElement $tool
                    if ($dependencies.Count -gt 0) {
                        $dependenciesStr = $dependencies -join ", "
                        $null = $sb.AppendLine("| ^ | *Dependencies:* $dependenciesStr | |")
                    }
                }
            }

            $null = $sb.AppendLine("")
        }
    } else {
        $null = $sb.AppendLine("## All Tools")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("| Category | Tool | Description | Tags |")
        $null = $sb.AppendLine("|----------|------|-------------|------|")

        $allTools = @()
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $categoryName = $category.name
            $tools = $category.SelectNodes("tools/tool")
            foreach ($tool in $tools) {
                $allTools += [PSCustomObject]@{
                    Category = $categoryName
                    Tool = $tool
                    Sequence = [int]$tool.SelectSingleNode("sequence").InnerText
                }
            }
        }

        $sortedTools = $allTools | Sort-Object -Property Category, Sequence

        foreach ($item in $sortedTools) {
            $tool = $item.Tool
            $categoryName = $item.Category
            $toolName = $tool.SelectSingleNode("name").InnerText
            $toolPath = $tool.SelectSingleNode("path").InnerText
            $toolDescription = $tool.SelectSingleNode("description").InnerText
            $toolTags = $tool.SelectSingleNode("tags")?.InnerText ?? ""

            $null = $sb.AppendLine("| $categoryName | [$toolName]($toolPath) | $toolDescription | $toolTags |")

            if ($IncludeDependencies) {
                $dependencies = Get-DependencyNames -ToolElement $tool
                if ($dependencies.Count -gt 0) {
                    $dependenciesStr = $dependencies -join ", "
                    $null = $sb.AppendLine("| ^ | ^ | *Dependencies:* $dependenciesStr | |")
                }
            }
        }
    }

    return $sb.ToString()
}

# Generate HTML documentation
function Export-HtmlDocumentation {
    $sb = [System.Text.StringBuilder]::new()
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $null = $sb.AppendLine("<!DOCTYPE html>")
    $null = $sb.AppendLine("<html lang='en'>")
    $null = $sb.AppendLine("<head>")
    $null = $sb.AppendLine("    <meta charset='UTF-8'>")
    $null = $sb.AppendLine("    <meta name='viewport' content='width=device-width, initial-scale=1.0'>")
    $null = $sb.AppendLine("    <title>AutoGen Toolbox Documentation</title>")
    $null = $sb.AppendLine("    <style>")
    $null = $sb.AppendLine("        body { font-family: -apple-system, BlinkMacSystemFont, Arial, sans-serif; line-height: 1.6; max-width: 1200px; margin: 0 auto; padding: 20px; color: #333; }")
    $null = $sb.AppendLine("        h1 { color: #0066cc; }")
    $null = $sb.AppendLine("        h2 { color: #0066cc; margin-top: 30px; border-bottom: 1px solid #ddd; padding-bottom: 10px; }")
    $null = $sb.AppendLine("        table { border-collapse: collapse; width: 100%; margin: 20px 0; }")
    $null = $sb.AppendLine("        th, td { text-align: left; padding: 12px; border-bottom: 1px solid #ddd; }")
    $null = $sb.AppendLine("        th { background-color: #f2f2f2; }")
    $null = $sb.AppendLine("        tr:hover { background-color: #f5f5f5; }")
    $null = $sb.AppendLine("        .timestamp { color: #666; font-size: 0.9em; margin-bottom: 20px; }")
    $null = $sb.AppendLine("        .dependency { font-style: italic; color: #666; }")
    $null = $sb.AppendLine("        .tag { display: inline-block; background-color: #e0e0e0; border-radius: 3px; padding: 2px 6px; margin: 2px; font-size: 0.8em; }")
    $null = $sb.AppendLine("    </style>")
    $null = $sb.AppendLine("</head>")
    $null = $sb.AppendLine("<body>")
    $null = $sb.AppendLine("    <h1>AutoGen Toolbox Documentation</h1>")
    $null = $sb.AppendLine("    <div class='timestamp'>Generated on: $timestamp | Version: $($catalog.toolbox_catalog.metadata.version)</div>")
    $null = $sb.AppendLine("    <p>$($catalog.toolbox_catalog.metadata.description)</p>")

    if ($GroupByCategory) {
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $categoryName = $category.name
            $categoryDescription = $category.description

            $null = $sb.AppendLine("    <h2>$categoryName</h2>")
            $null = $sb.AppendLine("    <p>$categoryDescription</p>")
            $null = $sb.AppendLine("    <table>")
            $null = $sb.AppendLine("        <tr>")
            $null = $sb.AppendLine("            <th>Tool</th>")
            $null = $sb.AppendLine("            <th>Description</th>")
            $null = $sb.AppendLine("            <th>Tags</th>")
            $null = $sb.AppendLine("        </tr>")

            $tools = $category.SelectNodes("tools/tool") | Sort-Object { [int]$_.SelectSingleNode("sequence").InnerText }

            foreach ($tool in $tools) {
                $toolName = $tool.SelectSingleNode("name").InnerText
                $toolPath = $tool.SelectSingleNode("path").InnerText
                $toolDescription = $tool.SelectSingleNode("description").InnerText
                $toolTags = $tool.SelectSingleNode("tags")?.InnerText ?? ""
                $toolId = $tool.SelectSingleNode("id").InnerText

                $tagsHtml = ""
                if ($toolTags -ne "") {
                    $tagsList = $toolTags -split ','
                    foreach ($tag in $tagsList) {
                        $tagsHtml += "<span class='tag'>$tag</span> "
                    }
                }

                $null = $sb.AppendLine("        <tr id='tool-$toolId'>")
                $null = $sb.AppendLine("            <td><a href='$toolPath'>$toolName</a></td>")
                $null = $sb.AppendLine("            <td>$toolDescription</td>")
                $null = $sb.AppendLine("            <td>$tagsHtml</td>")
                $null = $sb.AppendLine("        </tr>")

                if ($IncludeDependencies) {
                    $dependencies = Get-DependencyNames -ToolElement $tool
                    if ($dependencies.Count -gt 0) {
                        $dependenciesStr = $dependencies -join ", "
                        $null = $sb.AppendLine("        <tr>")
                        $null = $sb.AppendLine("            <td colspan='3'><div class='dependency'>Dependencies: $dependenciesStr</div></td>")
                        $null = $sb.AppendLine("        </tr>")
                    }
                }
            }

            $null = $sb.AppendLine("    </table>")
        }
    } else {
        $null = $sb.AppendLine("    <h2>All Tools</h2>")
        $null = $sb.AppendLine("    <table>")
        $null = $sb.AppendLine("        <tr>")
        $null = $sb.AppendLine("            <th>Category</th>")
        $null = $sb.AppendLine("            <th>Tool</th>")
        $null = $sb.AppendLine("            <th>Description</th>")
        $null = $sb.AppendLine("            <th>Tags</th>")
        $null = $sb.AppendLine("        </tr>")

        $allTools = @()
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $categoryName = $category.name
            $tools = $category.SelectNodes("tools/tool")
            foreach ($tool in $tools) {
                $allTools += [PSCustomObject]@{
                    Category = $categoryName
                    Tool = $tool
                    Sequence = [int]$tool.SelectSingleNode("sequence").InnerText
                }
            }
        }

        $sortedTools = $allTools | Sort-Object -Property Category, Sequence

        foreach ($item in $sortedTools) {
            $tool = $item.Tool
            $categoryName = $item.Category
            $toolName = $tool.SelectSingleNode("name").InnerText
            $toolPath = $tool.SelectSingleNode("path").InnerText
            $toolDescription = $tool.SelectSingleNode("description").InnerText
            $toolTags = $tool.SelectSingleNode("tags")?.InnerText ?? ""
            $toolId = $tool.SelectSingleNode("id").InnerText

            $tagsHtml = ""
            if ($toolTags -ne "") {
                $tagsList = $toolTags -split ','
                foreach ($tag in $tagsList) {
                    $tagsHtml += "<span class='tag'>$tag</span> "
                }
            }

            $null = $sb.AppendLine("        <tr id='tool-$toolId'>")
            $null = $sb.AppendLine("            <td>$categoryName</td>")
            $null = $sb.AppendLine("            <td><a href='$toolPath'>$toolName</a></td>")
            $null = $sb.AppendLine("            <td>$toolDescription</td>")
            $null = $sb.AppendLine("            <td>$tagsHtml</td>")
            $null = $sb.AppendLine("        </tr>")

            if ($IncludeDependencies) {
                $dependencies = Get-DependencyNames -ToolElement $tool
                if ($dependencies.Count -gt 0) {
                    $dependenciesStr = $dependencies -join ", "
                    $null = $sb.AppendLine("        <tr>")
                    $null = $sb.AppendLine("            <td colspan='4'><div class='dependency'>Dependencies: $dependenciesStr</div></td>")
                    $null = $sb.AppendLine("        </tr>")
                }
            }
        }

        $null = $sb.AppendLine("    </table>")
    }

    $null = $sb.AppendLine("</body>")
    $null = $sb.AppendLine("</html>")

    return $sb.ToString()
}

# Generate text documentation
function Export-TextDocumentation {
    $sb = [System.Text.StringBuilder]::new()
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $null = $sb.AppendLine("AUTOGEN TOOLBOX DOCUMENTATION")
    $null = $sb.AppendLine("==============================")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("Version: $($catalog.toolbox_catalog.metadata.version)")
    $null = $sb.AppendLine("Generated: $timestamp")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("$($catalog.toolbox_catalog.metadata.description)")
    $null = $sb.AppendLine("")

    if ($GroupByCategory) {
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $categoryName = $category.name
            $categoryDescription = $category.description

            $null = $sb.AppendLine("$categoryName")
            $null = $sb.AppendLine("".PadLeft($categoryName.Length, '-'))
            $null = $sb.AppendLine("")
            $null = $sb.AppendLine("$categoryDescription")
            $null = $sb.AppendLine("")

            $tools = $category.SelectNodes("tools/tool") | Sort-Object { [int]$_.SelectSingleNode("sequence").InnerText }

            foreach ($tool in $tools) {
                $toolName = $tool.SelectSingleNode("name").InnerText
                $toolPath = $tool.SelectSingleNode("path").InnerText
                $toolDescription = $tool.SelectSingleNode("description").InnerText
                $toolTags = $tool.SelectSingleNode("tags")?.InnerText ?? ""

                $null = $sb.AppendLine("  Name: $toolName")
                $null = $sb.AppendLine("  Path: $toolPath")
                $null = $sb.AppendLine("  Description: $toolDescription")
                if ($toolTags -ne "") {
                    $null = $sb.AppendLine("  Tags: $toolTags")
                }

                if ($IncludeDependencies) {
                    $dependencies = Get-DependencyNames -ToolElement $tool
                    if ($dependencies.Count -gt 0) {
                        $dependenciesStr = $dependencies -join ", "
                        $null = $sb.AppendLine("  Dependencies: $dependenciesStr")
                    }
                }

                $null = $sb.AppendLine("")
            }

            $null = $sb.AppendLine("")
        }
    } else {
        $null = $sb.AppendLine("All Tools")
        $null = $sb.AppendLine("---------")
        $null = $sb.AppendLine("")

        $allTools = @()
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $categoryName = $category.name
            $tools = $category.SelectNodes("tools/tool")
            foreach ($tool in $tools) {
                $allTools += [PSCustomObject]@{
                    Category = $categoryName
                    Tool = $tool
                    Sequence = [int]$tool.SelectSingleNode("sequence").InnerText
                }
            }
        }

        $sortedTools = $allTools | Sort-Object -Property Category, Sequence

        foreach ($item in $sortedTools) {
            $tool = $item.Tool
            $categoryName = $item.Category
            $toolName = $tool.SelectSingleNode("name").InnerText
            $toolPath = $tool.SelectSingleNode("path").InnerText
            $toolDescription = $tool.SelectSingleNode("description").InnerText
            $toolTags = $tool.SelectSingleNode("tags")?.InnerText ?? ""

            $null = $sb.AppendLine("  Category: $categoryName")
            $null = $sb.AppendLine("  Name: $toolName")
            $null = $sb.AppendLine("  Path: $toolPath")
            $null = $sb.AppendLine("  Description: $toolDescription")
            if ($toolTags -ne "") {
                $null = $sb.AppendLine("  Tags: $toolTags")
            }

            if ($IncludeDependencies) {
                $dependencies = Get-DependencyNames -ToolElement $tool
                if ($dependencies.Count -gt 0) {
                    $dependenciesStr = $dependencies -join ", "
                    $null = $sb.AppendLine("  Dependencies: $dependenciesStr")
                }
            }

            $null = $sb.AppendLine("")
        }
    }

    return $sb.ToString()
}

# Generate documentation based on the specified format
$documentationContent = $null
switch ($Format) {
    "markdown" {
        $documentationContent = Export-MarkdownDocumentation
        $outputFile = Join-Path $OutputPath "toolbox-documentation.md"
    }
    "html" {
        $documentationContent = Export-HtmlDocumentation
        $outputFile = Join-Path $OutputPath "toolbox-documentation.html"
    }
    "text" {
        $documentationContent = Export-TextDocumentation
        $outputFile = Join-Path $OutputPath "toolbox-documentation.txt"
    }
}

if ($documentationContent -ne $null) {
    $documentationContent | Out-File -FilePath $outputFile -Encoding utf8
    Write-Host "Documentation exported successfully at: $outputFile" -ForegroundColor Green
}
