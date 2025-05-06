# Pester tests for DirTagGroupManagement module

# Import the module using the full path
$modulePath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'DirTagGroupManagement.psm1'
if (-not (Test-Path $modulePath)) {
    throw "DirTagGroupManagement.psm1 not found at $modulePath. Ensure the module exists in .toolbox/modules/."
}
Import-Module $modulePath -Force

Describe "DirTagGroupManagement Module" {
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
    $testRootDir = Join-Path -Path $tempDir -ChildPath "DirTagGroupTests_$(Get-Random)"
    $testDocker = Join-Path -Path $testRootDir -ChildPath "docker"
    $testSwarm = Join-Path -Path $testRootDir -ChildPath "swarm"
    $testBuildKit = Join-Path -Path $testRootDir -ChildPath "buildkit"
    $testGPU = Join-Path -Path $testRootDir -ChildPath "gpu"

    BeforeAll {
        # Create test directories
        New-Item -Path $testRootDir -ItemType Directory -Force | Out-Null
        New-Item -Path $testDocker -ItemType Directory -Force | Out-Null
        New-Item -Path $testSwarm -ItemType Directory -Force | Out-Null
        New-Item -Path $testBuildKit -ItemType Directory -Force | Out-Null
        New-Item -Path $testGPU -ItemType Directory -Force | Out-Null
    }

    AfterAll {
        # Clean up test directories
        if (Test-Path $testRootDir) {
            Remove-Item -Path $testRootDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "DirTagGroup class and New-DirTagGroup function" {
        It "Should create a new DirTagGroup object" {
            $group = New-DirTagGroup -Name "TestGroup" -Description "Test description"
            $group | Should -Not -BeNullOrEmpty
            $group.Name | Should -Be "TestGroup"
            $group.Description | Should -Be "Test description"
        }

        It "Should add directories to a group" {
            $group = New-DirTagGroup -Name "TestGroup" -DirectoryPaths @($testDocker, $testSwarm)
            $group.DirectoryPaths.Count | Should -Be 2
            $group.DirectoryPaths[0] | Should -Be $testDocker
            $group.DirectoryPaths[1] | Should -Be $testSwarm
        }

        It "Should resolve directories from patterns" {
            $group = New-DirTagGroup -Name "TestGroup" -DirectoryPatterns @("$testRootDir\*")
            $directories = $group.ResolveDirectories()
            $directories.Count | Should -BeGreaterThan 0
            $directories | Should -Contain $testDocker
            $directories | Should -Contain $testSwarm
        }

        It "Should exclude directories based on patterns" {
            $group = New-DirTagGroup -Name "TestGroup" -DirectoryPatterns @("$testRootDir\*") -ExcludePatterns @("*swarm*")
            $directories = $group.ResolveDirectories()
            $directories | Should -Not -Contain $testSwarm
        }
    }

    Context "Get-GPUConfigurationDirTagGroup function" {
        It "Should return a valid group for GPU configuration" {
            $group = Get-GPUConfigurationDirTagGroup
            $group | Should -Not -BeNullOrEmpty
            $group.Name | Should -Be "GPUConfiguration"
            $group.DirectoryPaths.Count | Should -BeGreaterThan 0
        }
    }

    Context "Get-StdDirTagGroup function" {
        It "Should return a DevContainer group" {
            $group = Get-StdDirTagGroup -GroupName "DevContainer"
            $group | Should -Not -BeNullOrEmpty
            $group.Name | Should -Be "DevContainer"
        }

        It "Should return a Docker group" {
            $group = Get-StdDirTagGroup -GroupName "Docker"
            $group | Should -Not -BeNullOrEmpty
            $group.Name | Should -Be "Docker"
        }

        It "Should return a Swarm group" {
            $group = Get-StdDirTagGroup -GroupName "Swarm"
            $group | Should -Not -BeNullOrEmpty
            $group.Name | Should -Be "Swarm"
        }

        It "Should return a BuildKit group" {
            $group = Get-StdDirTagGroup -GroupName "BuildKit"
            $group | Should -Not -BeNullOrEmpty
            $group.Name | Should -Be "BuildKit"
        }

        It "Should return an All group" {
            $group = Get-StdDirTagGroup -GroupName "All"
            $group | Should -Not -BeNullOrEmpty
            $group.Name | Should -Be "All"
        }
    }

    Context "Invoke-DirTagGroupOperation function" {
        BeforeEach {
            # Create fresh DIR.TAG files for each test
            $null = New-DirTag -DirectoryPath $testDocker -TodoItems @("Configure Docker [OUTSTANDING]", "Set up networking [OUTSTANDING]")
            $null = New-DirTag -DirectoryPath $testSwarm -TodoItems @("Configure Swarm [OUTSTANDING]", "Set up networking [OUTSTANDING]")
            $null = New-DirTag -DirectoryPath $testBuildKit -TodoItems @("Configure BuildKit [OUTSTANDING]")
        }

        It "Should add a todo item to all DIR.TAG files in a group" {
            $group = New-DirTagGroup -Name "TestGroup" -DirectoryPaths @($testDocker, $testSwarm, $testBuildKit)
            $results = Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::Add) -TodoItem "Setup GPU support [OUTSTANDING]" -Force

            $results.Count | Should -Be 3
            $results[0].Success | Should -BeTrue
            $results[1].Success | Should -BeTrue
            $results[2].Success | Should -BeTrue

            # Verify the todo item was added to each file
            $dockerTag = Get-Content -Path (Join-Path -Path $testDocker -ChildPath "DIR.TAG") -Raw
            $swarmTag = Get-Content -Path (Join-Path -Path $testSwarm -ChildPath "DIR.TAG") -Raw
            $buildKitTag = Get-Content -Path (Join-Path -Path $testBuildKit -ChildPath "DIR.TAG") -Raw

            $dockerTag | Should -Match "Setup GPU support \[OUTSTANDING\]"
            $swarmTag | Should -Match "Setup GPU support \[OUTSTANDING\]"
            $buildKitTag | Should -Match "Setup GPU support \[OUTSTANDING\]"
        }

        It "Should update a todo item status in all DIR.TAG files in a group" {
            # First add the GPU item to all files
            $group = New-DirTagGroup -Name "TestGroup" -DirectoryPaths @($testDocker, $testSwarm, $testBuildKit)
            $null = Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::Add) -TodoItem "Setup GPU support [OUTSTANDING]" -Force

            # Now update its status
            $results = Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::Update) -TodoItem "Setup GPU support" -Status "DONE" -Force

            $results.Count | Should -Be 3
            $results[0].Success | Should -BeTrue
            $results[1].Success | Should -BeTrue
            $results[2].Success | Should -BeTrue

            # Verify the status was updated
            $dockerTag = Get-Content -Path (Join-Path -Path $testDocker -ChildPath "DIR.TAG") -Raw
            $swarmTag = Get-Content -Path (Join-Path -Path $testSwarm -ChildPath "DIR.TAG") -Raw
            $buildKitTag = Get-Content -Path (Join-Path -Path $testBuildKit -ChildPath "DIR.TAG") -Raw

            $dockerTag | Should -Match "Setup GPU support \[DONE\]"
            $swarmTag | Should -Match "Setup GPU support \[DONE\]"
            $buildKitTag | Should -Match "Setup GPU support \[DONE\]"
        }

        It "Should remove a todo item from all DIR.TAG files in a group" {
            # First add the GPU item to all files
            $group = New-DirTagGroup -Name "TestGroup" -DirectoryPaths @($testDocker, $testSwarm, $testBuildKit)
            $null = Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::Add) -TodoItem "Setup GPU support [OUTSTANDING]" -Force

            # Now remove it
            $results = Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::Remove) -TodoItem "Setup GPU support" -Force

            $results.Count | Should -Be 3
            $results[0].Success | Should -BeTrue
            $results[1].Success | Should -BeTrue
            $results[2].Success | Should -BeTrue

            # Verify the item was removed
            $dockerTag = Get-Content -Path (Join-Path -Path $testDocker -ChildPath "DIR.TAG") -Raw
            $swarmTag = Get-Content -Path (Join-Path -Path $testSwarm -ChildPath "DIR.TAG") -Raw
            $buildKitTag = Get-Content -Path (Join-Path -Path $testBuildKit -ChildPath "DIR.TAG") -Raw

            $dockerTag | Should -Not -Match "Setup GPU support"
            $swarmTag | Should -Not -Match "Setup GPU support"
            $buildKitTag | Should -Not -Match "Setup GPU support"
        }

        It "Should set status for all DIR.TAG files in a group" {
            $group = New-DirTagGroup -Name "TestGroup" -DirectoryPaths @($testDocker, $testSwarm, $testBuildKit)
            $results = Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::SetStatus) -Status "DONE" -Force

            $results.Count | Should -Be 3
            $results[0].Success | Should -BeTrue
            $results[1].Success | Should -BeTrue
            $results[2].Success | Should -BeTrue

            # Verify the status was set
            $dockerTag = Get-Content -Path (Join-Path -Path $testDocker -ChildPath "DIR.TAG") -Raw
            $swarmTag = Get-Content -Path (Join-Path -Path $testSwarm -ChildPath "DIR.TAG") -Raw
            $buildKitTag = Get-Content -Path (Join-Path -Path $testBuildKit -ChildPath "DIR.TAG") -Raw

            $dockerTag | Should -Match "status: DONE"
            $swarmTag | Should -Match "status: DONE"
            $buildKitTag | Should -Match "status: DONE"
        }

        It "Should validate all DIR.TAG files in a group" {
            $group = New-DirTagGroup -Name "TestGroup" -DirectoryPaths @($testDocker, $testSwarm, $testBuildKit)
            $results = Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::Validate)

            $results.Count | Should -Be 3
            $results[0].Success | Should -BeTrue
            $results[1].Success | Should -BeTrue
            $results[2].Success | Should -BeTrue
        }

        It "Should reorganize todo items in all DIR.TAG files in a group" {
            # Create a file with mixed status items
            $null = New-DirTag -DirectoryPath $testGPU -TodoItems @(
                "Item 1 [DONE]",
                "Item 2 [OUTSTANDING]",
                "Item 3 [PARTIALLY_COMPLETE]",
                "Item 4 with no status"
            ) -Force

            $group = New-DirTagGroup -Name "TestGroup" -DirectoryPaths @($testGPU)
            $results = Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::Reorganize) -Force

            $results.Count | Should -Be 1
            $results[0].Success | Should -BeTrue

            # Verify items were reorganized (outstanding first, then no status, then partial, then done)
            $gpuTag = Get-Content -Path (Join-Path -Path $testGPU -ChildPath "DIR.TAG") -Raw
            $lines = $gpuTag -split "`n"

            $outstandingIndex = $lines.IndexOf(($lines | Where-Object { $_ -match "Item 2 \[OUTSTANDING\]" }))
            $noStatusIndex = $lines.IndexOf(($lines | Where-Object { $_ -match "Item 4 with no status" }))
            $partialIndex = $lines.IndexOf(($lines | Where-Object { $_ -match "Item 3 \[PARTIALLY_COMPLETE\]" }))
            $doneIndex = $lines.IndexOf(($lines | Where-Object { $_ -match "Item 1 \[DONE\]" }))

            # Check ordering
            $outstandingIndex | Should -BeLessThan $partialIndex
            $partialIndex | Should -BeLessThan $doneIndex
        }
    }

    Context "GPU-specific functions" {
        BeforeEach {
            # Create fresh DIR.TAG files for each test
            $null = New-DirTag -DirectoryPath $testDocker -TodoItems @("Configure Docker [OUTSTANDING]", "Set up networking [OUTSTANDING]")
            $null = New-DirTag -DirectoryPath $testSwarm -TodoItems @("Configure Swarm [OUTSTANDING]", "Set up networking [OUTSTANDING]")
            $null = New-DirTag -DirectoryPath $testBuildKit -TodoItems @("Configure BuildKit [OUTSTANDING]")
            $null = New-DirTag -DirectoryPath $testGPU -TodoItems @("Setup GPU monitoring [OUTSTANDING]")
        }

        # For these tests, we'll use mocked group since we can't easily access the real GPU group in tests
        $mockGpuGroup = New-DirTagGroup -Name "MockGPUGroup" -DirectoryPaths @($testDocker, $testSwarm, $testBuildKit, $testGPU)

        # Mock the Get-GPUConfigurationDirTagGroup function to return our test group
        Mock Get-GPUConfigurationDirTagGroup {
            return $mockGpuGroup
        } -ModuleName DirTagGroupManagement

        It "Should add a GPU task to all DIR.TAG files" {
            $results = Add-GPUTaskToDirTags -TaskDescription "Configure NVIDIA drivers" -Status "OUTSTANDING" -Force

            # Verify the task was added
            $dockerTag = Get-Content -Path (Join-Path -Path $testDocker -ChildPath "DIR.TAG") -Raw
            $swarmTag = Get-Content -Path (Join-Path -Path $testSwarm -ChildPath "DIR.TAG") -Raw
            $buildKitTag = Get-Content -Path (Join-Path -Path $testBuildKit -ChildPath "DIR.TAG") -Raw
            $gpuTag = Get-Content -Path (Join-Path -Path $testGPU -ChildPath "DIR.TAG") -Raw

            $dockerTag | Should -Match "Configure NVIDIA drivers \[OUTSTANDING\]"
            $swarmTag | Should -Match "Configure NVIDIA drivers \[OUTSTANDING\]"
            $buildKitTag | Should -Match "Configure NVIDIA drivers \[OUTSTANDING\]"
            $gpuTag | Should -Match "Configure NVIDIA drivers \[OUTSTANDING\]"
        }

        It "Should update the status of a GPU task" {
            # First add the GPU task
            $null = Add-GPUTaskToDirTags -TaskDescription "Configure CUDA toolkit" -Status "OUTSTANDING" -Force

            # Now update its status
            $results = Update-GPUTaskStatus -TaskDescription "Configure CUDA toolkit" -Status "DONE" -Force

            # Verify the status was updated
            $dockerTag = Get-Content -Path (Join-Path -Path $testDocker -ChildPath "DIR.TAG") -Raw
            $swarmTag = Get-Content -Path (Join-Path -Path $testSwarm -ChildPath "DIR.TAG") -Raw
            $buildKitTag = Get-Content -Path (Join-Path -Path $testBuildKit -ChildPath "DIR.TAG") -Raw
            $gpuTag = Get-Content -Path (Join-Path -Path $testGPU -ChildPath "DIR.TAG") -Raw

            $dockerTag | Should -Match "Configure CUDA toolkit \[DONE\]"
            $swarmTag | Should -Match "Configure CUDA toolkit \[DONE\]"
            $buildKitTag | Should -Match "Configure CUDA toolkit \[DONE\]"
            $gpuTag | Should -Match "Configure CUDA toolkit \[DONE\]"
        }

        It "Should remove a GPU task" {
            # First add the GPU task
            $null = Add-GPUTaskToDirTags -TaskDescription "Configure GPU memory limits" -Status "OUTSTANDING" -Force

            # Now remove it
            $results = Remove-GPUTaskFromDirTags -TaskDescription "Configure GPU memory limits" -Force

            # Verify the task was removed
            $dockerTag = Get-Content -Path (Join-Path -Path $testDocker -ChildPath "DIR.TAG") -Raw
            $swarmTag = Get-Content -Path (Join-Path -Path $testSwarm -ChildPath "DIR.TAG") -Raw
            $buildKitTag = Get-Content -Path (Join-Path -Path $testBuildKit -ChildPath "DIR.TAG") -Raw
            $gpuTag = Get-Content -Path (Join-Path -Path $testGPU -ChildPath "DIR.TAG") -Raw

            $dockerTag | Should -Not -Match "Configure GPU memory limits"
            $swarmTag | Should -Not -Match "Configure GPU memory limits"
            $buildKitTag | Should -Not -Match "Configure GPU memory limits"
            $gpuTag | Should -Not -Match "Configure GPU memory limits"
        }

        It "Should test GPU DIR.TAG validity" {
            $results = Test-GPUDirTags
            $results | Should -Not -Contain $false
        }
    }
}
