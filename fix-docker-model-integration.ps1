# Fix Docker Model Integration Issues
# This script fixes issues with Docker Model Runner integration, XML schema validation,
# and removes references to unsupported modelsix Docker Model Integration Issues
# This script fixes issues        Write-Host "Replaced <name> with <n> for category: $($nElement.InnerText)" -ForegroundColor Yellowwith Docker Model Runner integration, XML schema validation,
# and removes references to unsupported models

# Define paths
$modelSettingsPath = "$PSScriptRoot\.config\host\model_settings.xml"
$dockerDocPath = "$PSScriptRoot\.config\host\docker_documentation.xml"
$schemaPath = "$PSScriptRoot\.github\schemas\docker_documentation_schema.xsd"

Write-Host "Starting Docker Model Integration fixes..." -ForegroundColor Cyan

# Fix model_settings.xml - Remove qwen2.5-coder:7b reference
Write-Host "Fixing model_settings.xml..." -ForegroundColor Yellow
[xml]$modelSettings = Get-Content -Path $modelSettingsPath
$modelsNode = $modelSettings.model_settings.models

# Remove the qwen2.5-coder:7b model node
$nodesToRemove = @()
foreach ($model in $modelsNode.model) {
    if ($model.n -eq "ai/qwen2.5-coder:7b") {
        $nodesToRemove += $model
    }
}

foreach ($node in $nodesToRemove) {
    $modelsNode.RemoveChild($node) | Out-Null
}

# Save the updated XML
$modelSettings.Save($modelSettingsPath)
Write-Host "Successfully removed qwen2.5-coder:7b from model_settings.xml" -ForegroundColor Green

# Fix docker_documentation_schema.xsd - Update to match XML structure
Write-Host "Fixing docker_documentation_schema.xsd..." -ForegroundColor Yellow
[xml]$schema = Get-Content -Path $schemaPath
$categorySequence = $schema.schema.element.complexType.sequence.element[1].complexType.sequence.element.complexType.sequence

# Fix the <n> vs <name> mismatch by replacing <name> with <n>
foreach ($element in $categorySequence.ChildNodes) {
    if ($element.Name -eq "name") {
        $element.Name = "n"
    }
}

# Save the updated schema
$schema.Save($schemaPath)
Write-Host "Successfully updated XML schema to use <n> tag" -ForegroundColor Green

# Fix docker_documentation.xml - Fix any inconsistencies
Write-Host "Fixing docker_documentation.xml..." -ForegroundColor Yellow
[xml]$dockerDoc = Get-Content -Path $dockerDocPath

# Check if the XML already uses <n> tags
$categories = $dockerDoc.SelectNodes("//category/n")
if ($categories.Count -gt 0) {
    Write-Host "XML already uses <n> tags - no changes needed" -ForegroundColor Green
    # Just for info, output the category names
    Write-Host "#text" -ForegroundColor DarkGray
    Write-Host "-----" -ForegroundColor DarkGray
    foreach ($node in $categories) {
        Write-Host $node.InnerText
    }
} else {
    # Ensure compatibility with schema
    $changed = $false
    foreach ($category in $dockerDoc.docker_documentation.categories.category) {
        # Check if we have a 'name' element instead of 'n'
        $nameNode = $category.SelectSingleNode("name")
        if ($null -ne $nameNode) {
            # Create a new <n> element
            $nElement = $dockerDoc.CreateElement("n")
            $nElement.InnerText = $nameNode.InnerText

            # Replace the old element
            $category.ReplaceChild($nElement, $nameNode)
            $changed = $true
            Write-Host "Replaced <name> with <n> for category: $($nElement.InnerText)" -ForegroundColor Yellow
        }
    }

    if ($changed) {
        $dockerDoc.Save($dockerDocPath)
        Write-Host "Fixed element name inconsistencies in docker_documentation.xml" -ForegroundColor Green
    } else {
        Write-Host "No changes needed in docker_documentation.xml" -ForegroundColor Green
    }
}

# Update custom dictionary to include Docker Model terms
Write-Host "Updating custom dictionary..." -ForegroundColor Yellow
$dictionaryPath = "$PSScriptRoot\.config\cspell-dictionary.txt"
$dictionary = Get-Content -Path $dictionaryPath

# Add Docker Model Runner specific terms if they don't exist
$termsToAdd = @(
    "ai/mistral",
    "ai/mistral-nemo",
    "ai/mxbai-embed-large",
    "ai/smollm2",
    "modelclient",
    "modelrunner",
    "docker-model-integration"
)

$dictionarySet = New-Object System.Collections.Generic.HashSet[string]
foreach ($line in $dictionary) {
    $dictionarySet.Add($line) | Out-Null
}

$added = $false
foreach ($term in $termsToAdd) {
    if (-not $dictionarySet.Contains($term)) {
        Add-Content -Path $dictionaryPath -Value $term
        Write-Host "Added '$term' to dictionary" -ForegroundColor Green
        $added = $true
    }
}

if (-not $added) {
    Write-Host "No new terms needed to be added to dictionary" -ForegroundColor Green
}

Write-Host "Docker Model Integration fixes completed." -ForegroundColor Cyan
