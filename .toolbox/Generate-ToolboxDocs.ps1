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

        $sb = New-Object System.Text.StringBuilder
        $null = $sb.AppendLine("# AutoGen Toolbox Documentation")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("> Generated on: $timestamp")
        $null = $sb.AppendLine("> Version: $($catalog.toolbox_catalog.metadata.version)")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("$($catalog.toolbox_catalog.metadata.description)")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("## Table of Contents")
        $null = $sb.AppendLine("")

        # Generate TOC
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $null = $sb.AppendLine("- [" + $category.name + "](#" + $category.id + ")")
        }

        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("## Categories and Tools")

        # Generate category and tool documentation
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $null = $sb.AppendLine("")
            $null = $sb.AppendLine("### " + $category.name + " {#" + $category.id + "}")
            $null = $sb.AppendLine("")
            $null = $sb.AppendLine($category.description)
            $null = $sb.AppendLine("")
            $null = $sb.AppendLine("| Tool | Description | Tags |")
            $null = $sb.AppendLine("|------|-------------|------|")

            foreach ($tool in $category.tools.tool) {
                $null = $sb.AppendLine("| [" + $tool.name + "](" + $tool.path.Replace("\", "/") + ") | " + $tool.description + " | " + $tool.tags + " |")
            }
        }

        # Write to file
        $sb.ToString() | Set-Content -Path $outputFile
        Write-Host "Markdown documentation generated: $outputFile" -ForegroundColor Green
    }

    "html" {
        $outputFile = Join-Path $OutputPath "toolbox-documentation.html"

        $sb = New-Object System.Text.StringBuilder
        $null = $sb.AppendLine("<!DOCTYPE html>")
        $null = $sb.AppendLine("<html lang='en'>")
        $null = $sb.AppendLine("<head>")
        $null = $sb.AppendLine("    <meta charset='UTF-8'>")
        $null = $sb.AppendLine("    <meta name='viewport' content='width=device-width, initial-scale=1.0'>")
        $null = $sb.AppendLine("    <title>AutoGen Toolbox Documentation</title>")
        $null = $sb.AppendLine("    <style>")
        $null = $sb.AppendLine("        body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }")
        $null = $sb.AppendLine("        h1, h2, h3 { color: #333; }")
        $null = $sb.AppendLine("        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }")
        $null = $sb.AppendLine("        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }")
        $null = $sb.AppendLine("        th { background-color: #f2f2f2; }")
        $null = $sb.AppendLine("        tr:nth-child(even) { background-color: #f9f9f9; }")
        $null = $sb.AppendLine("        .tag { background-color: #e7f3fe; border-radius: 4px; padding: 2px 6px; margin-right: 4px; }")
        $null = $sb.AppendLine("        .timestamp { color: #666; font-style: italic; margin-bottom: 20px; }")
        $null = $sb.AppendLine("    </style>")
        $null = $sb.AppendLine("</head>")
        $null = $sb.AppendLine("<body>")
        $null = $sb.AppendLine("    <h1>AutoGen Toolbox Documentation</h1>")
        $null = $sb.AppendLine("    <div class='timestamp'>Generated on: $timestamp | Version: $($catalog.toolbox_catalog.metadata.version)</div>")
        $null = $sb.AppendLine("    <p>$($catalog.toolbox_catalog.metadata.description)</p>")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("    <h2>Table of Contents</h2>")
        $null = $sb.AppendLine("    <ul>")

        # Generate TOC
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $null = $sb.AppendLine("        <li><a href='#" + $category.id + "'>" + $category.name + "</a></li>")
        }

        $null = $sb.AppendLine("    </ul>")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("    <h2>Categories and Tools</h2>")

        # Generate category and tool documentation
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $null = $sb.AppendLine("")
            $null = $sb.AppendLine("    <h3 id='" + $category.id + "'>" + $category.name + "</h3>")
            $null = $sb.AppendLine("    <p>" + $category.description + "</p>")
            $null = $sb.AppendLine("    <table>")
            $null = $sb.AppendLine("        <tr>")
            $null = $sb.AppendLine("            <th>Tool</th>")
            $null = $sb.AppendLine("            <th>Description</th>")
            $null = $sb.AppendLine("            <th>Tags</th>")
            $null = $sb.AppendLine("        </tr>")

            foreach ($tool in $category.tools.tool) {
                $tags = $tool.tags -split ','
                $tagHtml = ""
                foreach ($tag in $tags) {
                    $tagHtml += "<span class='tag'>" + $tag.Trim() + "</span> "
                }

                $null = $sb.AppendLine("        <tr>")
                $null = $sb.AppendLine("            <td><a href='" + $tool.path.Replace("\", "/") + "'>" + $tool.name + "</a></td>")
                $null = $sb.AppendLine("            <td>" + $tool.description + "</td>")
                $null = $sb.AppendLine("            <td>" + $tagHtml + "</td>")
                $null = $sb.AppendLine("        </tr>")
            }

            $null = $sb.AppendLine("    </table>")
        }

        $null = $sb.AppendLine("</body>")
        $null = $sb.AppendLine("</html>")

        # Write to file
        $sb.ToString() | Set-Content -Path $outputFile
        Write-Host "HTML documentation generated: $outputFile" -ForegroundColor Green
    }

    "text" {
        $outputFile = Join-Path $OutputPath "toolbox-documentation.txt"

        $sb = New-Object System.Text.StringBuilder
        $null = $sb.AppendLine("AUTOGEN TOOLBOX DOCUMENTATION")
        $null = $sb.AppendLine("=============================")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("Generated on: $timestamp")
        $null = $sb.AppendLine("Version: $($catalog.toolbox_catalog.metadata.version)")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("$($catalog.toolbox_catalog.metadata.description)")
        $null = $sb.AppendLine("")

        # Generate category and tool documentation
        foreach ($category in $catalog.toolbox_catalog.categories.category) {
            $null = $sb.AppendLine("")
            $null = $sb.AppendLine($category.name.ToUpper())
            $null = $sb.AppendLine(("-" * $category.name.Length))
            $null = $sb.AppendLine("")
            $null = $sb.AppendLine($category.description)
            $null = $sb.AppendLine("")
            $null = $sb.AppendLine("Tools:")
            $null = $sb.AppendLine("------")

            foreach ($tool in $category.tools.tool) {
                $null = $sb.AppendLine("")
                $null = $sb.AppendLine("* " + $tool.name)
                $null = $sb.AppendLine("  Description: " + $tool.description)
                $null = $sb.AppendLine("  Path: " + $tool.path)
                $null = $sb.AppendLine("  Tags: " + $tool.tags)
            }
        }

        # Write to file
        $sb.ToString() | Set-Content -Path $outputFile
        Write-Host "Text documentation generated: $outputFile" -ForegroundColor Green
    }
}

Write-Host "Documentation generation completed" -ForegroundColor Green
