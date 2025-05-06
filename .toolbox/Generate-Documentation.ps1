# Generate documentation from the toolbox catalog
# This script reads the toolbox-catalog.xml file and generates documentation in various formats

param(
    [Parameter()]
    [ValidateSet("markdown", "html", "text")]
    [string]$Format = "markdown",

    [Parameter()]
    [string]$OutputPath
)

Write-Host "Generating toolbox documentation in $Format format..." -ForegroundColor Cyan

# Define paths
$catalogPath = "$PSScriptRoot\toolbox-catalog.xml"
$defaultOutputPath = "$PSScriptRoot\documentation"

# Use provided output path or default
if (-not $OutputPath) {
    $OutputPath = $defaultOutputPath
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
}

# Load the catalog XML
[xml]$catalog = Get-Content -Path $catalogPath

# Generate timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

switch ($Format) {
    "markdown" {
        $outputFile = Join-Path $OutputPath "toolbox-documentation.md"

        $content = @"
# AutoGen Toolbox Documentation

> Generated on: $timestamp
> Version: $($catalog.toolbox_catalog.metadata.version)

$($catalog.toolbox_catalog.metadata.description)

## Table of Contents

"@

        # Generate TOC
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $content += "- [" + $category.name + "](#" + $category.id + ")" + "`n"
        }

        $content += "`n## Categories and Tools`n"

        # Generate category and tool documentation
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $content += "`n### " + $category.name + " {#" + $category.id + "}`n`n"
            $content += $category.description + "`n`n"
            $content += "| Tool | Description | Tags |`n"
            $content += "|------|-------------|------|`n"            foreach ($tool in $category.tools.tool) {
                $content += "| [" + $tool.name + "](" + $tool.path.Replace("\", "/") + ") | " + $tool.description + " | " + $tool.tags + " |`n"
            }
        }

        # Write to file
        $content | Set-Content -Path $outputFile
        Write-Host "Markdown documentation generated: $outputFile" -ForegroundColor Green
    }

    "html" {
        $outputFile = Join-Path $OutputPath "toolbox-documentation.html"

        $content = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AutoGen Toolbox Documentation</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
        h1, h2, h3 { color: #333; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .tag { background-color: #e7f3fe; border-radius: 4px; padding: 2px 6px; margin-right: 4px; }
        .timestamp { color: #666; font-style: italic; margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>AutoGen Toolbox Documentation</h1>
    <div class="timestamp">Generated on: $timestamp | Version: $($catalog.toolbox_catalog.metadata.version)</div>
    <p>$($catalog.toolbox_catalog.metadata.description)</p>

    <h2>Table of Contents</h2>
    <ul>
"@

        # Generate TOC
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $content += "        <li><a href=`"#" + $category.id + "`">" + $category.name + "</a></li>`n"
        }

        $content += @"
    </ul>

    <h2>Categories and Tools</h2>
"@

        # Generate category and tool documentation
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $content += @"

    <h3 id="$($category.id)">$($category.name)</h3>
    <p>$($category.description)</p>
    <table>
        <tr>
            <th>Tool</th>
            <th>Description</th>
            <th>Tags</th>
        </tr>
"@

            foreach ($tool in $category.tools.tool) {
                $tags = $tool.tags -split ','
                $tagHtml = ""
                foreach ($tag in $tags) {
                    $tagHtml += "<span class=`"tag`">$tag</span>"
                }

                $content += @"
        <tr>
            <td><a href="$($tool.path.Replace("\", "/"))">$($tool.name)</a></td>
            <td>$($tool.description)</td>
            <td>$tagHtml</td>
        </tr>
"@
            }

            $content += "    </table>`n"
        }

        $content += @"
</body>
</html>
"@

        # Write to file
        $content | Set-Content -Path $outputFile
        Write-Host "HTML documentation generated: $outputFile" -ForegroundColor Green
    }

    "text" {
        $outputFile = Join-Path $OutputPath "toolbox-documentation.txt"

        $content = @"
AUTOGEN TOOLBOX DOCUMENTATION
=============================

Generated on: $timestamp
Version: $($catalog.toolbox_catalog.metadata.version)

$($catalog.toolbox_catalog.metadata.description)

"@

        # Generate category and tool documentation
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $content += @"

$($category.name.ToUpper())
$('-' * $category.name.Length)

$($category.description)

Tools:
------
"@

            foreach ($tool in $category.tools.tool) {
                $content += @"

* $($tool.name)
  Description: $($tool.description)
  Path: $($tool.path)
  Tags: $($tool.tags)
"@
            }
        }

        # Write to file
        $content | Set-Content -Path $outputFile
        Write-Host "Text documentation generated: $outputFile" -ForegroundColor Green
    }
}

Write-Host "Documentation generation completed" -ForegroundColor Green
