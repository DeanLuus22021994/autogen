# Script to provide a mapping to the .toolbox directory
Write-Host "Mapping .scripts/toolbox to .toolbox directory..." -ForegroundColor Cyan

# Get available tools
$tools = Get-ChildItem -Path "$PSScriptRoot/../../.toolbox" -Recurse -Filter "*.ps1" | 
         Where-Object { -not $_.FullName.Contains("Update-") }

Write-Host "
Available tools:" -ForegroundColor Green
foreach ($tool in $tools) {
    $category = $tool.Directory.Name
    $relativePath = $tool.FullName.Replace([System.IO.Path]::GetFullPath("$PSScriptRoot/../../"), "")
    Write-Host "  [$category] $($tool.BaseName) - .$relativePath" -ForegroundColor Yellow
}

Write-Host "
To use a tool, run it from the repository root:" -ForegroundColor Cyan
Write-Host "  .\.toolbox\<category>\<script-name>.ps1" -ForegroundColor White
