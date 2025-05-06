# Pester tests for the DirTagManagement module

# Import the module using the full path
$modulePath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'DirTagManagement.psm1'
if (-not (Test-Path $modulePath)) {
    throw "DirTagManagement.psm1 not found at $modulePath. Ensure the module exists in .toolbox/modules/."
}
Import-Module $modulePath -Force

Describe "DirTagManagement Module" {
    # Use a robust temp directory for containerized and cross-platform environments
    $tempDir = $env:TEMP
    if (-not $tempDir -or $tempDir -eq "") {
        $tempDir = Join-Path -Path $PWD -ChildPath 'tmp'
    }
    if (-not (Test-Path $tempDir)) {
        try {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        } catch {
            throw "Failed to create temp directory: $tempDir. Error: $_"
        }
    }

    # Create a test directory structure
    $testRootDir = Join-Path -Path $tempDir -ChildPath "DirTagTests_$(Get-Random)"
    $testConfigDir = Join-Path -Path $testRootDir -ChildPath ".config"
    $testSubDir = Join-Path -Path $testConfigDir -ChildPath "subdir"

    BeforeAll {
        # Create test directories
        New-Item -Path $testRootDir -ItemType Directory -Force | Out-Null
        New-Item -Path $testConfigDir -ItemType Directory -Force | Out-Null
        New-Item -Path $testSubDir -ItemType Directory -Force | Out-Null
    }

    AfterAll {
        # Clean up test directories
        if (Test-Path $testRootDir) {
            Remove-Item -Path $testRootDir -Recurse -Force
        }
    }

    Context "New-DirTag" {
        It "Creates a new DIR.TAG file" {
            $result = New-DirTag -DirectoryPath $testConfigDir -Description "Test Config Directory"
            $result | Should -BeTrue
            (Test-Path -Path (Join-Path -Path $testConfigDir -ChildPath "DIR.TAG")) | Should -BeTrue
            (Test-Path -Path (Join-Path -Path $testConfigDir -ChildPath ".gitkeep")) | Should -BeTrue
        }

        It "Creates a DIR.TAG file with custom TodoItems" {
            $todoItems = @("Custom todo item 1", "Custom todo item 2")
            $result = New-DirTag -DirectoryPath $testSubDir -Description "Test Subdir" -TodoItems $todoItems
            $result | Should -BeTrue

            $content = Get-Content -Path (Join-Path -Path $testSubDir -ChildPath "DIR.TAG") -Raw
            $content | Should -Match "Custom todo item 1"
            $content | Should -Match "Custom todo item 2"
        }

        It "Overwrites existing DIR.TAG with -Force" {
            $result = New-DirTag -DirectoryPath $testConfigDir -Description "Updated Description" -Force
            $result | Should -BeTrue

            $content = Get-Content -Path (Join-Path -Path $testConfigDir -ChildPath "DIR.TAG") -Raw
            $content | Should -Match "Updated Description"
        }
    }

    Context "Update-DirTag" {
        It "Updates an existing DIR.TAG file" {
            # First create a file
            New-DirTag -DirectoryPath $testConfigDir -Description "Initial Description"

            # Then update it
            $result = Update-DirTag -DirectoryPath $testConfigDir -Status "IN_PROGRESS" -Description "Updated via Update-DirTag"
            $result | Should -BeTrue

            $content = Get-Content -Path (Join-Path -Path $testConfigDir -ChildPath "DIR.TAG") -Raw
            $content | Should -Match "status: IN_PROGRESS"
            $content | Should -Match "Updated via Update-DirTag"
        }

        It "Creates a new DIR.TAG if one doesn't exist" {
            $newDir = Join-Path -Path $testRootDir -ChildPath "newdir"
            New-Item -Path $newDir -ItemType Directory -Force | Out-Null

            $result = Update-DirTag -DirectoryPath $newDir -Status "PLANNED"
            $result | Should -BeTrue

            $content = Get-Content -Path (Join-Path -Path $newDir -ChildPath "DIR.TAG") -Raw
            $content | Should -Match "status: PLANNED"
        }

        It "Preserves GUID when updating" {
            # Create a file with a known GUID
            $guid = [System.Guid]::NewGuid().ToString()
            $tagPath = Join-Path -Path $testSubDir -ChildPath "DIR.TAG"

            @"
#INDEX: test/path
#GUID: $guid
#TODO:
  - Test item
status: TEST
updated: 2023-01-01T00:00:00Z
description: |
  Test description
"@ | Set-Content -Path $tagPath

            # Update the file
            $result = Update-DirTag -DirectoryPath $testSubDir -Status "UPDATED"
            $result | Should -BeTrue

            $content = Get-Content -Path $tagPath -Raw
            $content | Should -Match "#GUID: $guid"
            $content | Should -Match "status: UPDATED"
        }
    }

    Context "Test-DirTag" {
        It "Returns true for a valid DIR.TAG" {
            New-DirTag -DirectoryPath $testConfigDir -Description "Valid Test" -Force
            $result = Test-DirTag -DirectoryPath $testConfigDir
            $result | Should -BeTrue
        }

        It "Returns false for a directory without DIR.TAG" {
            $emptyDir = Join-Path -Path $testRootDir -ChildPath "emptydir"
            New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null

            $result = Test-DirTag -DirectoryPath $emptyDir
            $result | Should -BeFalse
        }

        It "Returns detailed results with -Detailed switch" {
            New-DirTag -DirectoryPath $testConfigDir -Description "Valid Test" -Force
            $result = Test-DirTag -DirectoryPath $testConfigDir -Detailed

            $result.Path | Should -Be $testConfigDir
            $result.Valid | Should -BeTrue
            $result.TagExists | Should -BeTrue
            $result.Content | Should -Not -BeNullOrEmpty
            $result.Issues.Count | Should -Be 0
        }

        It "Identifies issues in invalid DIR.TAG files" {
            $invalidDir = Join-Path -Path $testRootDir -ChildPath "invaliddir"
            New-Item -Path $invalidDir -ItemType Directory -Force | Out-Null

            @"
#INDEX: wrong/path
status: INVALID
"@ | Set-Content -Path (Join-Path -Path $invalidDir -ChildPath "DIR.TAG")

            $result = Test-DirTag -DirectoryPath $invalidDir -Detailed

            $result.Valid | Should -BeFalse
            $result.Issues.Count | Should -BeGreaterThan 0
        }
    }

    Context "Find-DirTags" {
        It "Finds all DIR.TAG files" {
            # Create multiple DIR.TAG files
            New-DirTag -DirectoryPath $testConfigDir -Force
            New-DirTag -DirectoryPath $testSubDir -Force

            $results = Find-DirTags -RootPath $testRootDir
            $results.Count | Should -BeGreaterOrEqual 2
        }

        It "Includes content with -IncludeContent switch" {
            $results = Find-DirTags -RootPath $testRootDir -IncludeContent
            $results[0].Content | Should -Not -BeNullOrEmpty
        }

        It "Validates all files with -ValidateAll switch" {
            $results = Find-DirTags -RootPath $testRootDir -ValidateAll
            $results[0].Valid | Should -Not -BeNullOrEmpty
        }
    }
}
