# Pester tests for the ProblemManagement module

# Import the module using the full path
$modulePath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'ProblemManagement.psm1'
if (-not (Test-Path $modulePath)) {
    throw "ProblemManagement.psm1 not found at $modulePath. Ensure the module exists in .toolbox/modules/."
}
Import-Module $modulePath -Force

# Import DirTagManagement for integration tests
$dirTagModulePath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'DirTagManagement.psm1'
if (Test-Path $dirTagModulePath) {
    Import-Module $dirTagModulePath -Force
}

Describe "ProblemManagement Module" {
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
    $testRootDir = Join-Path -Path $tempDir -ChildPath "ProblemTests_$(Get-Random)"
    $testPsDir = Join-Path -Path $testRootDir -ChildPath "PowerShell"
    $testTextDir = Join-Path -Path $testRootDir -ChildPath "Text"

    BeforeAll {
        # Create test directories
        New-Item -Path $testRootDir -ItemType Directory -Force | Out-Null
        New-Item -Path $testPsDir -ItemType Directory -Force | Out-Null
        New-Item -Path $testTextDir -ItemType Directory -Force | Out-Null

        # Create a valid PowerShell file
        @"
function Test-Function {
    param(
        [string]`$param1
    )

    Write-Output `$param1
}
"@ | Out-File -FilePath (Join-Path -Path $testPsDir -ChildPath "Valid.ps1") -Encoding utf8

        # Create an invalid PowerShell file
        @"
function Invalid-Syntax {
    Write-Output "Missing closing bracket
}
"@ | Out-File -FilePath (Join-Path -Path $testPsDir -ChildPath "Invalid.ps1") -Encoding utf8

        # Create a text file with trailing whitespace
        @"
This is a test file
with some content
and trailing whitespace
"@ | Out-File -FilePath (Join-Path -Path $testTextDir -ChildPath "WithTrailingSpace.txt") -Encoding utf8

        # Create test XML config
        $configDir = Join-Path -Path $testRootDir -ChildPath ".config\dir-tag"
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null

        @"
<?xml version="1.0" encoding="UTF-8"?>
<dir_tag_configuration>
  <problem_mapping>
    <problem_type>
      <name>error</name>
      <status>OUTSTANDING</status>
      <priority>high</priority>
    </problem_type>
    <problem_type>
      <name>warning</name>
      <status>PARTIALLY_COMPLETE</status>
      <priority>medium</priority>
    </problem_type>
    <problem_type>
      <name>info</name>
      <status>NOT_STARTED</status>
      <priority>low</priority>
    </problem_type>
  </problem_mapping>
</dir_tag_configuration>
"@ | Out-File -FilePath (Join-Path -Path $configDir -ChildPath "dir-tag-config.xml") -Encoding utf8
    }

    AfterAll {
        # Clean up test directories
        if (Test-Path $testRootDir) {
            Remove-Item -Path $testRootDir -Recurse -Force
        }
    }

    Context "Get-ProblemConfig" {
        It "Retrieves problem configuration from XML" {
            $configPath = Join-Path -Path $testRootDir -ChildPath ".config\dir-tag\dir-tag-config.xml"
            $config = Get-ProblemConfig -ConfigPath $configPath
            $config | Should -Not -BeNullOrEmpty
            $config.problem_type | Should -HaveCount 3
            $config.problem_type[0].name | Should -Be "error"
            $config.problem_type[0].status | Should -Be "OUTSTANDING"
        }

        It "Returns null for non-existent config" {
            $config = Get-ProblemConfig -ConfigPath "NonExistentPath"
            $config | Should -BeNullOrEmpty
        }
    }

    Context "Get-DirectoryProblems" {
        It "Finds problems in PowerShell files" {
            $problems = Get-DirectoryProblems -DirectoryPath $testPsDir
            $problems | Should -Not -BeNullOrEmpty
            $problems | Where-Object { $_.FilePath -like "*Invalid.ps1" } | Should -Not -BeNullOrEmpty
            ($problems | Where-Object { $_.Type -eq 'error' }).Count | Should -BeGreaterThan 0
        }

        It "Finds generic problems in text files" {
            $problems = Get-DirectoryProblems -DirectoryPath $testTextDir
            $problems | Should -Not -BeNullOrEmpty
            $problems | Where-Object { $_.RuleId -eq 'TrailingWhitespace' } | Should -Not -BeNullOrEmpty
        }

        It "Returns empty array for non-existent directory" {
            $problems = Get-DirectoryProblems -DirectoryPath "NonExistentPath"
            $problems | Should -BeNullOrEmpty
        }

        It "Filters problems by type" {
            $problems = Get-DirectoryProblems -DirectoryPath $testRootDir -ProblemTypesFilter "warning|info"
            $problems | Where-Object { $_.Type -eq 'error' } | Should -BeNullOrEmpty
        }
    }

    Context "Update-DirTagFromProblems" {
        It "Creates a DIR.TAG file based on problems" -Skip:(-not (Get-Command -Name Update-DirTag -ErrorAction SilentlyContinue)) {
            $result = Update-DirTagFromProblems -DirectoryPath $testPsDir -Force
            $result | Should -BeTrue
            Test-Path -Path (Join-Path -Path $testPsDir -ChildPath "DIR.TAG") | Should -BeTrue

            $tagContent = Get-Content -Path (Join-Path -Path $testPsDir -ChildPath "DIR.TAG") -Raw
            $tagContent | Should -Match "OUTSTANDING"  # Should have outstanding status due to errors
        }
    }
}
