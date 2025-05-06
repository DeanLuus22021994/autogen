<#
.SYNOPSIS
    Registers a new tool in the toolbox catalog with proper GUID and sequencing.
.DESCRIPTION
    Adds a new tool to the toolbox-catalog.xml file with a unique GUID,
    appropriate sequence number, and optionally specifies dependencies.
.PARAMETER Path
    The path to the tool script relative to the repository root.
.PARAMETER Name
    The name of the tool (without extension).
.PARAMETER Description
    A short description of the tool's functionality.
.PARAMETER Category
    The category to which the tool belongs (must exist in the catalog).
.PARAMETER Tags
    Comma-separated list of tags for the tool.
.PARAMETER Sequence
    Optional sequence number. If not provided, will be placed at the end of the category.
.PARAMETER DependsOn
    Optional array of tool IDs that this tool depends on.
.PARAMETER BeforeTool
    Optional tool ID to place this tool before in the sequence.
.PARAMETER AfterTool
    Optional tool ID to place this tool after in the sequence.
.EXAMPLE
    .\Register-Tool.ps1 -Path ".toolbox\docker\New-DockerTool.ps1" -Name "New-DockerTool" -Description "Creates a new Docker container" -Category "docker" -Tags "docker,container,creation"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Description,

    [Parameter(Mandatory = $true)]
    [string]$Category,

    [Parameter(Mandatory = $false)]
    [string]$Tags = "",

    [Parameter(Mandatory = $false)]
    [int]$Sequence = -1,

    [Parameter(Mandatory = $false)]
    [string[]]$DependsOn = @(),

    [Parameter(Mandatory = $false)]
    [string]$BeforeTool = "",

    [Parameter(Mandatory = $false)]
    [string]$AfterTool = ""
)

function New-Guid {
    return [guid]::NewGuid().ToString()
}

function Get-MaxSequence {
    param (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$CategoryElement
    )

    $maxSequence = 0
    $tools = $CategoryElement.SelectNodes("tools/tool")

    foreach ($tool in $tools) {
        $toolSequence = [int]$tool.SelectSingleNode("sequence").InnerText
        if ($toolSequence -gt $maxSequence) {
            $maxSequence = $toolSequence
        }
    }

    return $maxSequence
}

function Get-ToolSequence {
    param (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$CategoryElement,

        [Parameter(Mandatory = $false)]
        [int]$RequestedSequence = -1,

        [Parameter(Mandatory = $false)]
        [string]$BeforeTool = "",

        [Parameter(Mandatory = $false)]
        [string]$AfterTool = ""
    )

    if ($RequestedSequence -gt 0) {
        return $RequestedSequence
    }

    if ($BeforeTool -ne "") {
        $beforeToolElement = $CategoryElement.SelectSingleNode("tools/tool[id='$BeforeTool']")
        if ($beforeToolElement -ne $null) {
            $beforeSequence = [int]$beforeToolElement.SelectSingleNode("sequence").InnerText
            # Find the tool with the highest sequence less than the before tool's sequence
            $prevSequence = 0
            $tools = $CategoryElement.SelectNodes("tools/tool")
            foreach ($tool in $tools) {
                $toolSequence = [int]$tool.SelectSingleNode("sequence").InnerText
                if ($toolSequence -lt $beforeSequence -and $toolSequence -gt $prevSequence) {
                    $prevSequence = $toolSequence
                }
            }

            if ($prevSequence -eq 0) {
                # No tool before the target, so use half the target's sequence
                return [math]::Max(1, [math]::Floor($beforeSequence / 2))
            } else {
                # Place halfway between previous and target
                return $prevSequence + [math]::Floor(($beforeSequence - $prevSequence) / 2)
            }
        }
    }

    if ($AfterTool -ne "") {
        $afterToolElement = $CategoryElement.SelectSingleNode("tools/tool[id='$AfterTool']")
        if ($afterToolElement -ne $null) {
            $afterSequence = [int]$afterToolElement.SelectSingleNode("sequence").InnerText
            # Find the tool with the lowest sequence greater than the after tool's sequence
            $nextSequence = [int]::MaxValue
            $tools = $CategoryElement.SelectNodes("tools/tool")
            foreach ($tool in $tools) {
                $toolSequence = [int]$tool.SelectSingleNode("sequence").InnerText
                if ($toolSequence -gt $afterSequence -and $toolSequence -lt $nextSequence) {
                    $nextSequence = $toolSequence
                }
            }

            if ($nextSequence -eq [int]::MaxValue) {
                # No tool after the target, so add 10 to the target's sequence
                return $afterSequence + 10
            } else {
                # Place halfway between target and next
                return $afterSequence + [math]::Floor(($nextSequence - $afterSequence) / 2)
            }
        }
    }

    # Default: place at the end with a gap of 10
    $maxSequence = Get-MaxSequence -CategoryElement $CategoryElement
    return $maxSequence + 10
}

# Validate the tool path exists
if (-not (Test-Path $Path)) {
    Write-Error "Tool script not found at path: $Path"
    exit 1
}

# Load the catalog XML
$catalogPath = "$PSScriptRoot\toolbox-catalog.xml"
if (-not (Test-Path $catalogPath)) {
    Write-Error "Toolbox catalog not found at: $catalogPath"
    exit 1
}

$catalogXml = [xml](Get-Content $catalogPath)

# Find the category
$categoryElement = $catalogXml.SelectSingleNode("//category[name='$Category']")
if ($categoryElement -eq $null) {
    Write-Error "Category '$Category' not found in the toolbox catalog."
    exit 1
}

# Check for existing tool with same path
$existingTool = $categoryElement.SelectSingleNode("tools/tool[path='$Path']")
if ($existingTool -ne $null) {
    Write-Error "A tool with path '$Path' already exists in the catalog."
    exit 1
}

# Validate dependencies
foreach ($dependency in $DependsOn) {
    $dependencyTool = $catalogXml.SelectSingleNode("//tool[id='$dependency']")
    if ($dependencyTool -eq $null) {
        Write-Error "Dependency tool with ID '$dependency' not found in the catalog."
        exit 1
    }
}

# Validate before/after tools
if ($BeforeTool -ne "" -and $AfterTool -ne "") {
    Write-Error "Cannot specify both BeforeTool and AfterTool parameters."
    exit 1
}

if ($BeforeTool -ne "") {
    $beforeToolElement = $catalogXml.SelectSingleNode("//tool[id='$BeforeTool']")
    if ($beforeToolElement -eq $null) {
        Write-Error "BeforeTool with ID '$BeforeTool' not found in the catalog."
        exit 1
    }
}

if ($AfterTool -ne "") {
    $afterToolElement = $catalogXml.SelectSingleNode("//tool[id='$AfterTool']")
    if ($afterToolElement -eq $null) {
        Write-Error "AfterTool with ID '$AfterTool' not found in the catalog."
        exit 1
    }
}

# Generate GUID for the tool
$toolId = New-Guid

# Determine sequence number
$toolSequence = Get-ToolSequence -CategoryElement $categoryElement -RequestedSequence $Sequence -BeforeTool $BeforeTool -AfterTool $AfterTool

# Create the new tool element
$toolsElement = $categoryElement.SelectSingleNode("tools")
$newTool = $catalogXml.CreateElement("tool")

$idElement = $catalogXml.CreateElement("id")
$idElement.InnerText = $toolId
$newTool.AppendChild($idElement)

$nameElement = $catalogXml.CreateElement("name")
$nameElement.InnerText = $Name
$newTool.AppendChild($nameElement)

$descriptionElement = $catalogXml.CreateElement("description")
$descriptionElement.InnerText = $Description
$newTool.AppendChild($descriptionElement)

$pathElement = $catalogXml.CreateElement("path")
$pathElement.InnerText = $Path
$newTool.AppendChild($pathElement)

$sequenceElement = $catalogXml.CreateElement("sequence")
$sequenceElement.InnerText = $toolSequence.ToString()
$newTool.AppendChild($sequenceElement)

if ($Tags -ne "") {
    $tagsElement = $catalogXml.CreateElement("tags")
    $tagsElement.InnerText = $Tags
    $newTool.AppendChild($tagsElement)
}

if ($DependsOn.Count -gt 0) {
    $dependenciesElement = $catalogXml.CreateElement("dependencies")
    foreach ($dependency in $DependsOn) {
        $dependencyElement = $catalogXml.CreateElement("dependency")
        $dependencyElement.InnerText = $dependency
        $dependenciesElement.AppendChild($dependencyElement)
    }
    $newTool.AppendChild($dependenciesElement)
}

# Add the new tool to the catalog
$toolsElement.AppendChild($newTool)

# Update the metadata
$metadataElement = $catalogXml.SelectSingleNode("//metadata")
$updatedElement = $metadataElement.SelectSingleNode("updated")
$updatedElement.InnerText = [DateTime]::UtcNow.ToString("o")

# Save the updated catalog
$catalogXml.Save($catalogPath)

Write-Host "Tool '$Name' successfully registered with ID: $toolId" -ForegroundColor Green
Write-Host "Tool added to category '$Category' with sequence number $toolSequence" -ForegroundColor Green

# Suggest next steps
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  - Update documentation: .\Generate-ToolboxDocs.ps1" -ForegroundColor Cyan
Write-Host "  - Test the toolbox environment: .\testing\Test-ToolboxEnvironment.ps1" -ForegroundColor Cyan