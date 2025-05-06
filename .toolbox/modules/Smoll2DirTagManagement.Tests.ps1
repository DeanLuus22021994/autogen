# Pester tests for smoll2/RAM disk DIR.TAG management

# Import the required modules
$modulePath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'DirTagGroupManagement.psm1'
if (-not (Test-Path $modulePath)) {
    throw "DirTagGroupManagement.psm1 not found at $modulePath. Ensure the module exists in .toolbox/modules/."
}
Import-Module $modulePath -Force

# Import the sync script as a module for testing
$syncScriptPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "..\docker\Sync-Smoll2DirTags.ps1"
if (-not (Test-Path $syncScriptPath)) {
    throw "Sync-Smoll2DirTags.ps1 not found at $syncScriptPath. Ensure the script exists in .toolbox/docker/."
}

Describe "Smoll2/RAM Disk DIR.TAG Management" {
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
    $testRootDir = Join-Path -Path $tempDir -ChildPath "Smoll2DirTagTests_$(Get-Random)"
    $testDevContainerDir = Join-Path -Path $testRootDir -ChildPath ".devcontainer"
    $testDockerDir = Join-Path -Path $testDevContainerDir -ChildPath "docker"
    $testSwarmDir = Join-Path -Path $testDevContainerDir -ChildPath "swarm"
    $testToolboxDir = Join-Path -Path $testRootDir -ChildPath ".toolbox"
    $testDocsDir = Join-Path -Path $testRootDir -ChildPath "docs"

    BeforeAll {
        # Create test directories
        New-Item -Path $testRootDir -ItemType Directory -Force | Out-Null
        New-Item -Path $testDevContainerDir -ItemType Directory -Force | Out-Null
        New-Item -Path $testDockerDir -ItemType Directory -Force | Out-Null
        New-Item -Path $testSwarmDir -ItemType Directory -Force | Out-Null
        New-Item -Path $testToolboxDir -ItemType Directory -Force | Out-Null
        New-Item -Path $testDocsDir -ItemType Directory -Force | Out-Null

        # Mock the git command used in the script
        Mock git { return $testRootDir } -ParameterFilter { $args -contains 'rev-parse' }
    }

    AfterAll {
        # Clean up test directories
        if (Test-Path $testRootDir) {
            Remove-Item -Path $testRootDir -Recurse -Force
        }
    }

    Context "Smoll2/RAM Disk DIR.TAG Group Creation" {
        It "Should create a DIR.TAG group for smoll2/RAM disk related directories" {
            # Define the function with local scope for testing
            function Get-Smoll2RamDiskDirTagGroup {
                $group = New-DirTagGroup -Name "Smoll2RamDisk" -Description "DIR.TAG files related to smoll2 LLM with RAM disk optimization"

                $group.AddDirectory("$testRootDir\.devcontainer")
                $group.AddDirectory("$testRootDir\.devcontainer\docker")
                $group.AddDirectory("$testRootDir\.devcontainer\swarm")
                $group.AddDirectory("$testRootDir\.toolbox")
                $group.AddDirectory("$testRootDir\docs")

                $group.Metadata = @{
                    Category = "Performance"
                    Priority = "High"
                    RelatedTech = @("RAM Disk", "Docker", "Swarm", "GPU", "LLM", "smoll2")
                }

                return $group
            }

            $group = Get-Smoll2RamDiskDirTagGroup
            $group | Should -Not -BeNullOrEmpty
            $group.Name | Should -Be "Smoll2RamDisk"
            $group.DirectoryPaths.Count | Should -Be 5
            $group.Metadata.Category | Should -Be "Performance"
        }
    }

    Context "Smoll2/RAM Disk DIR.TAG Creation" {
        It "Should create DIR.TAG files in smoll2/RAM disk related directories" {
            # Create a test DIR.TAG with smoll2/RAM disk TODO items
            $todoItems = @(
                "Configure RAM disk for smoll2 model weights [OUTSTANDING]",
                "Implement smoll2 model with Docker Model Runner [OUTSTANDING]"
            )

            New-DirTag -DirectoryPath $testDockerDir -TodoItems $todoItems -Force

            $dirTagPath = Join-Path -Path $testDockerDir -ChildPath "DIR.TAG"
            Test-Path $dirTagPath | Should -Be $true

            $content = Get-Content -Path $dirTagPath -Raw
            $content | Should -Match "Configure RAM disk for smoll2 model weights"
            $content | Should -Match "Implement smoll2 model with Docker Model Runner"
        }
    }

    Context "Smoll2/RAM Disk DIR.TAG Group Operations" {
        BeforeEach {
            # Create test DIR.TAG files
            New-DirTag -DirectoryPath $testDevContainerDir -Description "DevContainer for smoll2" -TodoItems @("Setup test [OUTSTANDING]") -Force
            New-DirTag -DirectoryPath $testDockerDir -Description "Docker for smoll2" -TodoItems @("Setup test [OUTSTANDING]") -Force
            New-DirTag -DirectoryPath $testSwarmDir -Description "Swarm for smoll2" -TodoItems @("Setup test [OUTSTANDING]") -Force
        }

        It "Should add smoll2/RAM disk TODO items to a group of DIR.TAG files" {
            # Create a group with test directories
            $group = New-DirTagGroup -Name "TestSmoll2Group" -DirectoryPaths @(
                $testDevContainerDir,
                $testDockerDir,
                $testSwarmDir
            )

            $todoItem = "Configure RAM disk for smoll2 model weights [OUTSTANDING]"

            # Add the TODO item to all DIR.TAG files in the group
            $result = Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::Add) -TodoItem $todoItem -Force

            # Check results
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3

            # Check all DIR.TAG files were updated
            $dirTagPaths = @(
                (Join-Path -Path $testDevContainerDir -ChildPath "DIR.TAG"),
                (Join-Path -Path $testDockerDir -ChildPath "DIR.TAG"),
                (Join-Path -Path $testSwarmDir -ChildPath "DIR.TAG")
            )

            foreach ($path in $dirTagPaths) {
                $content = Get-Content -Path $path -Raw
                $content | Should -Match ([regex]::Escape($todoItem))
            }
        }

        It "Should update the status of smoll2/RAM disk TODO items in a group" {
            # Create a group with test directories
            $group = New-DirTagGroup -Name "TestSmoll2Group" -DirectoryPaths @(
                $testDevContainerDir,
                $testDockerDir,
                $testSwarmDir
            )

            $todoItem = "Configure RAM disk for smoll2 model weights"
            $newStatus = "DONE"

            # First add the item to all DIR.TAG files
            Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::Add) -TodoItem "$todoItem [OUTSTANDING]" -Force | Out-Null

            # Now update the status
            $result = Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::Update) -TodoItem $todoItem -Status $newStatus -Force

            # Check results
            $result | Should -Not -BeNullOrEmpty

            # Check all DIR.TAG files were updated with the new status
            $dirTagPaths = @(
                (Join-Path -Path $testDevContainerDir -ChildPath "DIR.TAG"),
                (Join-Path -Path $testDockerDir -ChildPath "DIR.TAG"),
                (Join-Path -Path $testSwarmDir -ChildPath "DIR.TAG")
            )

            foreach ($path in $dirTagPaths) {
                $content = Get-Content -Path $path -Raw
                $content | Should -Match ([regex]::Escape("$todoItem [$newStatus]"))
            }
        }
    }
}
