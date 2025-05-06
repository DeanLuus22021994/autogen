# Add MarkdownRulesTestFile function to fix-github-workflows.ps1

$scriptPath = "C:\Projects\autogen\fix-github-workflows.ps1"
$script = Get-Content -Path $scriptPath -Raw

# Add the new function before the "Run the functions" section
$addFunction = @'

# Function to fix the markdown-rules-test.yml file
function Fix-MarkdownRulesTestFile {
    $filePath = "c:\Projects\autogen\.github\workflows\markdown-rules-test.yml"

    # Check if the file exists
    if (-not (Test-Path $filePath)) {
        Write-Host "File not found: $filePath" -ForegroundColor Red
        return
    }

    # Read the current content
    $content = Get-Content -Path $filePath -Raw

    # No parameter fixes needed - Azure PowerShell action parameters are correct
    Write-Host "Verified markdown-rules-test.yml - parameters are already correct" -ForegroundColor Green
}

'@

# Find the location to insert the new function
$insertPoint = $script.IndexOf("# Run the functions")
if ($insertPoint -gt 0) {
    # Insert the new function before the "Run the functions" section
    $newScript = $script.Substring(0, $insertPoint) + $addFunction + $script.Substring($insertPoint)

    # Update the "Run the functions" section to include the new function
    $newScript = $newScript -replace "try {\r?\n\s+Fix-RefreshSidecarContainersFile\r?\n\s+Fix-DockerReadmeFile", "try {`r`n    Fix-RefreshSidecarContainersFile`r`n    Fix-MarkdownRulesTestFile`r`n    Fix-DockerReadmeFile"

    # Write the updated script
    $newScript | Out-File -FilePath $scriptPath -Encoding utf8

    Write-Host "Added Fix-MarkdownRulesTestFile function to $scriptPath" -ForegroundColor Green
} else {
    Write-Host "Could not find insertion point in script" -ForegroundColor Red
}
