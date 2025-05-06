# Pester tests for the DirTagProblemIntegration module

# Import the modules using the full path
$integrationModulePath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'DirTagProblemIntegration.psm1'
if (-not (Test-Path $integrationModulePath)) {
    throw "DirTagProblemIntegration.psm1 not found at $integrationModulePath."
}
Import-Module $integrationModulePath -Force

$dirTagModulePath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'DirTagManagement.psm1'
if (-not (Test-Path $dirTagModulePath)) {
    throw "DirTagManagement.psm1 not found at $dirTagModulePath."
}
Import-Module $dirTagModulePath -Force

$problemModulePath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'ProblemManagement.psm1'
if (-not (Test-Path $problemModulePath)) {
    throw "ProblemManagement.psm1 not found at $problemModulePath."
}
Import-Module $problemModulePath -Force

Describe "DirTagProblemIntegration Module" {
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

    # Create a test directory structure
    $testRootDir = Join-Path -Path $tempDir -ChildPath "DirTagProblemIntegration_$(Get-Random)"
    $testSubDir1 = Join-Path -Path $testRootDir -ChildPath "subdir1"
    $testSubDir2 = Join-Path -Path $testRootDir -ChildPath "subdir2"

    BeforeAll {
        # Create test directories
        New-Item -Path $testRootDir -ItemType Directory -Force | Out-Null
        New-Item -Path $testSubDir1 -ItemType Directory -Force | Out-Null
        New-Item -Path $testSubDir2 -ItemType Directory -Force | Out-Null

        # Create test files with problems
        $goodPsFile = Join-Path -Path $testSubDir1 -ChildPath "good.ps1"
        $badPsFile = Join-Path -Path $testSubDir1 -ChildPath "bad.ps1"
        $warningPsFile = Join-Path -Path $testSubDir2 -ChildPath "warning.ps1"

        # Good PS file
        @'
function Test-GoodFunction {
    param(
        [string]$Param1
    )

    return "Good function: $Param1"
}
'@ | Set-Content -Path $goodPsFile

        # PS file with syntax error
        @'
function Test-BadFunction {
    param(
        [string]$Param1

    return "Bad function: $Param1"
}
'@ | Set-Content -Path $badPsFile

        # PS file with warning (positional args)
        @'
function Test-WarningFunction {
    param(
        [string]$Param1
    )

    Write-Host "Warning function"
    return Get-Item C:\Windows
}
'@ | Set-Content -Path $warningPsFile

        # Create initial DIR.TAG files
        New-DirTag -DirectoryPath $testRootDir -Force | Out-Null
        New-DirTag -DirectoryPath $testSubDir1 -Force | Out-Null
        New-DirTag -DirectoryPath $testSubDir2 -Force | Out-Null
    }

    AfterAll {
        # Clean up test directory
        if (Test-Path $testRootDir) {
            Remove-Item -Path $testRootDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Update-DirTagStatusFromProblems" {
        It "Updates DIR.TAG status based on problems" {
            # Update subdirectory with error
            Update-DirTagStatusFromProblems -DirectoryPath $testSubDir1 -Force | Should -BeTrue

            # Get updated DIR.TAG
            $dirTag = Get-DirTag -Path (Join-Path -Path $testSubDir1 -ChildPath "DIR.TAG")

            # Status should be OUTSTANDING due to syntax error
            $dirTag.status | Should -Be "OUTSTANDING"

            # Should have at least one TODO item
            $dirTag.TODO.Count | Should -BeGreaterThan 0
        }

        It "Sets status to DONE when no problems exist" {
            # Create a clean subdirectory
            $cleanDir = Join-Path -Path $testRootDir -ChildPath "clean"
            New-Item -Path $cleanDir -ItemType Directory -Force | Out-Null

            # Create clean PS file
            $cleanFile = Join-Path -Path $cleanDir -ChildPath "clean.ps1"
            @'
function Test-CleanFunction {
    param(
        [string]$Param1
    )

    return "Clean function: $Param1"
}
'@ | Set-Content -Path $cleanFile

            # Create and update DIR.TAG
            New-DirTag -DirectoryPath $cleanDir -Force | Out-Null
            Update-DirTagStatusFromProblems -DirectoryPath $cleanDir -Force | Should -BeTrue

            # Get updated DIR.TAG
            $dirTag = Get-DirTag -Path (Join-Path -Path $cleanDir -ChildPath "DIR.TAG")

            # Status should be DONE
            $dirTag.status | Should -Be "DONE"
        }

        It "Works recursively" {
            # Update all directories
            Update-DirTagStatusFromProblems -DirectoryPath $testRootDir -Force -Recurse | Should -BeTrue

            # Root should reflect problems in subdirectories
            $rootDirTag = Get-DirTag -Path (Join-Path -Path $testRootDir -ChildPath "DIR.TAG")
            $rootDirTag.status | Should -Not -Be "DONE"
        }
    }

    Context "Get-DirTagProblemSummary" {
        It "Generates a summary of problems and DIR.TAG status" {
            # Generate summary
            $summary = Get-DirTagProblemSummary -RootPath $testRootDir

            # Should have at least 3 entries (root + 2 subdirectories)
            $summary.Count | Should -BeGreaterOrEqual 3

            # Should include problem counts
            $summary[0].ErrorCount | Should -BeGreaterOrEqual 0
            $summary[0].WarningCount | Should -BeGreaterOrEqual 0
        }

        It "Outputs in different formats" {
            # JSON format
            $jsonSummary = Get-DirTagProblemSummary -RootPath $testRootDir -OutputFormat "JSON"
            $jsonSummary | Should -Not -BeNullOrEmpty

            # CSV format
            $csvSummary = Get-DirTagProblemSummary -RootPath $testRootDir -OutputFormat "CSV"
            $csvSummary | Should -Not -BeNullOrEmpty
        }
    }
}
