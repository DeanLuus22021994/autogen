# .github/linting/run-lint-check.ps1
# Script to validate the markdown linting configuration

[CmdletBinding()]
param()

# Get the directory of the current script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Function to validate a JSON configuration file
function Test-JsonConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path -Path $FilePath)) {
        Write-Error "Configuration file not found: $FilePath"
        return $false
    }

    try {
        $content = Get-Content -Path $FilePath -Raw
        $null = $content | ConvertFrom-Json
        Write-Host "✓ Valid JSON configuration: $FilePath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Invalid JSON configuration: $FilePath - $_"
        return $false
    }
}

# Function to check if a rules directory exists and contains valid files
function Test-RulesDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath
    )

    if (-not (Test-Path -Path $DirectoryPath)) {
        Write-Error "Rules directory not found: $DirectoryPath"
        return $false
    }

    $ruleFiles = Get-ChildItem -Path $DirectoryPath -Filter "*.js" -File

    if ($ruleFiles.Count -eq 0) {
        Write-Warning "No rule files found in: $DirectoryPath"
        return $false
    }

    $allValid = $true

    foreach ($file in $ruleFiles) {
        try {
            $content = Get-Content -Path $file.FullName -Raw
            if ($content -notmatch "module\.exports\s*=") {
                Write-Warning "Rule file may not correctly export module: $($file.FullName)"
                $allValid = $false
            }
            else {
                Write-Host "✓ Valid rule file: $($file.Name)" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Error reading rule file $($file.FullName): $_"
            $allValid = $false
        }
    }

    return $allValid
}

# Main validation logic
$configValid = $true

# Check configuration files
$configFiles = @(
    (Join-Path -Path $scriptPath -ChildPath ".markdownlint-cli2.jsonc"),
    (Join-Path -Path $scriptPath -ChildPath ".markdownlint.json"),
    (Join-Path -Path $scriptPath -ChildPath ".markdownlintrc")
)

foreach ($file in $configFiles) {
    $configValid = $configValid -and (Test-JsonConfiguration -FilePath $file)
}

# Check rules directory
$rulesDir = Join-Path -Path $scriptPath -ChildPath "rules"
$rulesValid = Test-RulesDirectory -DirectoryPath $rulesDir

if ($configValid -and $rulesValid) {
    Write-Host "All linting configurations are valid!" -ForegroundColor Green
    exit 0
}
else {
    Write-Warning "Some linting configurations have issues. See above for details."
    exit 1
}
