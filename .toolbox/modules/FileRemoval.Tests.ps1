# Pester tests for Remove-FileWithConfirmation


# Import the module using the full path to the .psm1 file in the modules directory (containerization best practice)
$modulePath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'FileRemoval.psm1'
if (-not (Test-Path $modulePath)) {
    throw "FileRemoval.psm1 not found at $modulePath. Ensure the module exists in .toolbox/modules/."
}
Import-Module $modulePath -Force

Describe "Remove-FileWithConfirmation" {
    # Use a robust temp directory for containerized and cross-platform environments
    $tempDir = $env:TEMP
    if (-not $tempDir -or $tempDir -eq "") {
        $tempDir = Join-Path -Path $PWD -ChildPath 'tmp'
    }
    if (-not (Test-Path $tempDir)) {
        try {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        } catch {
            throw "Failed to create temp directory: $tempDir. Error: $($_.Exception.Message)"
        }
    }
    # Fallback to $PWD/tmp if $tempDir is still not valid
    if (-not (Test-Path $tempDir)) {
        $tempDir = Join-Path -Path $PWD -ChildPath 'tmp'
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
    }
    $testFile = Join-Path $tempDir "testfile_removal.txt"
    Write-Host "[DIAGNOSTIC] tempDir: $tempDir"
    Write-Host "[DIAGNOSTIC] testFile: $testFile"
    if (-not $testFile -or $testFile -eq "") { throw "testFile path is null or empty! tempDir: $tempDir" }
    BeforeAll {
        try {
            Set-Content -Path $testFile -Value "test"
        } catch {
            throw "Failed to create test file: $testFile. Error: $($_.Exception.Message)"
        }
    }
    It "Removes an existing file" {
        Remove-FileWithConfirmation -FilePath $testFile -Force | Out-Null
        (Test-Path $testFile) | Should -BeFalse
    }
    It "Handles non-existent file gracefully" {
        { Remove-FileWithConfirmation -FilePath $testFile -Force } | Should -Not -Throw
    }
}
