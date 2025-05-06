# PowerShell module for centralized DIR.TAG group management
# Supports batch operations on DIR.TAG files across multiple directories

#Requires -Version 5.1

# Ensure compatibility with existing DirTagManagement module
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "DirTagManagement.psm1") -Force

# Environment and path handling setup
function Initialize-EnvironmentPaths {
    [CmdletBinding()]
    param()

    # Determine repository root
    if (-not $env:REPO_ROOT) {
        # Default case: try to find repository root
        $currentPath = $PSScriptRoot
        while ($currentPath -and -not (Test-Path (Join-Path $currentPath ".git"))) {
            $currentPath = Split-Path $currentPath -Parent
        }

        if ($currentPath) {
            $env:REPO_ROOT = $currentPath
        } else {
            # Fallback: use relative paths from current module
            $env:REPO_ROOT = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
        }
    }

    # Check if running in container
    if ($env:CONTAINER_ENVIRONMENT -or (Test-Path "/.dockerenv")) {
        $script:IsContainer = $true
    } else {
        $script:IsContainer = $false
    }

    Write-Verbose "Repository root: $env:REPO_ROOT"
    Write-Verbose "Running in container: $script:IsContainer"
}

# Initialize environment
Initialize-EnvironmentPaths

# Enum for group operations types
enum DirTagGroupOperation {
    Add = 0          # Add a new task to TODO list
    Remove = 1       # Remove a task from TODO list
    Update = 2       # Update a task status or description
    SetStatus = 3    # Set overall status of DIR.TAG files
    Validate = 4     # Validate DIR.TAG files in a group
    Propagate = 5    # Propagate common tasks to child directories
    Reorganize = 6   # Reorganize TODO items based on status
    Sync = 7         # Synchronize GPU-related tasks across related directories
}

# Define DirTagGroup class for better structure and functionality
class DirTagGroup {
    [string]$Name
    [string]$Description
    [string[]]$DirectoryPaths
    [string[]]$DirectoryPatterns
    [string[]]$ExcludePatterns
    [string]$Tags
    [bool]$IncludeSubdirectories
    [hashtable]$Metadata

    DirTagGroup([string]$name) {
        $this.Name = $name
        $this.DirectoryPaths = @()
        $this.DirectoryPatterns = @()
        $this.ExcludePatterns = @()
        $this.IncludeSubdirectories = $false
        $this.Metadata = @{}
    }

    [void]AddDirectory([string]$path) {
        # Normalize path to repository-relative
        $normalizedPath = $this.NormalizePath($path)

        if (-not ($this.DirectoryPaths -contains $normalizedPath)) {
            $this.DirectoryPaths += $normalizedPath
        }
    }

    [void]AddDirectoryPattern([string]$pattern) {
        # Normalize pattern to repository-relative
        $normalizedPattern = $this.NormalizePattern($pattern)

        if (-not ($this.DirectoryPatterns -contains $normalizedPattern)) {
            $this.DirectoryPatterns += $normalizedPattern
        }
    }

    [void]AddExcludePattern([string]$pattern) {
        if (-not ($this.ExcludePatterns -contains $pattern)) {
            $this.ExcludePatterns += $pattern
        }
    }

    [string]NormalizePath([string]$path) {
        # If path is absolute, convert to repo-relative
        if ([System.IO.Path]::IsPathRooted($path)) {
            if ($path.StartsWith($env:REPO_ROOT, [StringComparison]::OrdinalIgnoreCase)) {
                $relativePath = $path.Substring($env:REPO_ROOT.Length).TrimStart('\', '/')
                return $relativePath
            } else {
                Write-Warning "Path '$path' is outside repository root. Using as-is."
                return $path
            }
        }

        return $path
    }

    [string]NormalizePattern([string]$pattern) {
        # Replace absolute path parts with repo-relative paths
        if ($pattern.StartsWith($env:REPO_ROOT, [StringComparison]::OrdinalIgnoreCase)) {
            $relativePattern = $pattern.Substring($env:REPO_ROOT.Length).TrimStart('\', '/')
            $relativePattern = $relativePattern.Replace("\**\", "/**/" )
            return $relativePattern
        }

        return $pattern
    }

    [string[]]ResolveDirectories() {
        $allDirs = @()

        # Add explicitly specified directories
        foreach ($dir in $this.DirectoryPaths) {
            $fullPath = if ([System.IO.Path]::IsPathRooted($dir)) {
                $dir
            } else {
                Join-Path $env:REPO_ROOT $dir
            }

            if (Test-Path -Path $fullPath -PathType Container) {
                $allDirs += $fullPath
            }
        }

        # Add directories matching patterns
        foreach ($pattern in $this.DirectoryPatterns) {
            $fullPattern = if ([System.IO.Path]::IsPathRooted($pattern)) {
                $pattern
            } else {
                Join-Path $env:REPO_ROOT $pattern
            }

            $dirs = Get-ChildItem -Path $fullPattern -Directory -Recurse:$this.IncludeSubdirectories |
                Where-Object { $_.FullName -notin $allDirs }

            $allDirs += $dirs.FullName
        }

        # Filter out excluded directories
        if ($this.ExcludePatterns.Count -gt 0) {
            $excludeRegex = ($this.ExcludePatterns | ForEach-Object { [regex]::Escape($_) }) -join '|'
            $allDirs = $allDirs | Where-Object { $_ -notmatch $excludeRegex }
        }

        return $allDirs
    }
}

function New-DirTagGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Description = "Directory group for batch DIR.TAG operations",

        [Parameter(Mandatory = $false)]
        [string[]]$DirectoryPaths = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$DirectoryPatterns = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludePatterns = @('node_modules', '.git', 'bin', 'obj'),

        [Parameter(Mandatory = $false)]
        [switch]$IncludeSubdirectories
    )

    # Always use repository-relative paths
    $repoRoot = $env:REPO_ROOT
    $normalize = { param($p) if ([System.IO.Path]::IsPathRooted($p)) { $p.Substring($repoRoot.Length).TrimStart('\','/') } else { $p } }

    $group = [PSCustomObject]@{
        Name = $Name
        Description = $Description
        DirectoryPaths = $DirectoryPaths | ForEach-Object { &$normalize $_ }
        DirectoryPatterns = $DirectoryPatterns | ForEach-Object { &$normalize $_ }
        ExcludePatterns = $ExcludePatterns
        IncludeSubdirectories = $IncludeSubdirectories
    }
    return $group
}

function Get-GPUConfigurationDirTagGroup {
    [CmdletBinding()]
    param()

    # Create a group for GPU-related DIR.TAG files
    $group = New-DirTagGroup -Name "GPUConfiguration" -Description "DIR.TAG files related to GPU configuration and optimization"

    # Add common GPU-related directories using relative paths
    $group.AddDirectory(".devcontainer")
    $group.AddDirectory(".devcontainer/swarm")
    $group.AddDirectory(".devcontainer/buildkit")
    $group.AddDirectory(".devcontainer/docker")
    $group.AddDirectory(".toolbox/docker")
    $group.AddDirectory(".toolbox/docker/swarm-compose")
    $group.AddDirectory(".toolbox/modules")

    # Add pattern for any docker-related directories that might contain GPU configurations
    $group.AddDirectoryPattern("**/*gpu*")
    $group.AddDirectoryPattern("**/*nvidia*")

    # Metadata for GPU group
    $group.Metadata = @{
        Category = "Infrastructure"
        Priority = "High"
        RelatedTech = @("NVIDIA", "Docker", "Swarm", "GPU", "CUDA")
    }

    return $group
}

function Invoke-DirTagGroupOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [DirTagGroup]$Group,

        [Parameter(Mandatory = $true, Position = 1)]
        [DirTagGroupOperation]$Operation,

        [Parameter(Mandatory = $false)]
        [string]$TodoItem,

        [Parameter(Mandatory = $false)]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )

    # Resolve all directories in the group
    $directories = $Group.ResolveDirectories()

    if ($directories.Count -eq 0) {
        Write-Warning "No directories found in group '$($Group.Name)'"
        return $null
    }

    Write-Verbose "Found $($directories.Count) directories in group '$($Group.Name)'"

    $results = @()

    foreach ($dir in $directories) {
        $result = [PSCustomObject]@{
            Directory = $dir
            Success = $false
            Message = ""
            OperationType = $Operation
        }

        # Skip processing if -WhatIf is specified
        if ($WhatIf) {
            $result.Message = "Would process DIR.TAG in $dir"
            $results += $result
            continue
        }

        try {
            switch ($Operation) {
                ([DirTagGroupOperation]::Add) {
                    if (-not $TodoItem) {
                        $result.Message = "TodoItem parameter is required for Add operation"
                        break
                    }

                    $dirTagPath = Join-Path -Path $dir -ChildPath "DIR.TAG"

                    if (Test-Path $dirTagPath) {
                        # Read existing content
                        $content = Get-Content -Path $dirTagPath -Raw

                        # Check if item already exists
                        if ($content -match [regex]::Escape($TodoItem)) {
                            $result.Message = "Todo item already exists in $dir"
                            $result.Success = $true
                            break
                        }

                        # Extract existing TODO items
                        $todoItems = @()
                        if ($content -match '#TODO:\s*\n((?:\s*-\s*.+\n)+)') {
                            $todoItems = $matches[1] -split "`n" |
                                Where-Object { $_ -match '\s*-\s*(.+)' } |
                                ForEach-Object { $matches[1].Trim() }
                        }

                        # Add new item
                        $todoItems += $TodoItem

                        # Update DIR.TAG
                        $params = @{
                            DirectoryPath = $dir
                            TodoItems = $todoItems
                            Force = $Force
                        }

                        $updateResult = Update-DirTag @params
                        $result.Success = $updateResult.Success
                        $result.Message = "Added todo item to $dir"
                    }
                    else {
                        # Create new DIR.TAG with the item
                        $params = @{
                            DirectoryPath = $dir
                            TodoItems = @($TodoItem)
                            Force = $Force
                        }

                        $newResult = New-DirTag @params
                        $result.Success = $newResult
                        $result.Message = "Created new DIR.TAG with todo item in $dir"
                    }
                }

                ([DirTagGroupOperation]::Remove) {
                    if (-not $TodoItem) {
                        $result.Message = "TodoItem parameter is required for Remove operation"
                        break
                    }

                    $dirTagPath = Join-Path -Path $dir -ChildPath "DIR.TAG"

                    if (Test-Path $dirTagPath) {
                        # Read existing content
                        $content = Get-Content -Path $dirTagPath -Raw

                        # Extract existing TODO items
                        $todoItems = @()
                        if ($content -match '#TODO:\s*\n((?:\s*-\s*.+\n)+)') {
                            $todoItems = $matches[1] -split "`n" |
                                Where-Object { $_ -match '\s*-\s*(.+)' } |
                                ForEach-Object { $matches[1].Trim() }
                        }

                        # Remove matching items
                        $originalCount = $todoItems.Count
                        $todoItems = $todoItems | Where-Object { $_ -notmatch [regex]::Escape($TodoItem) }

                        if ($todoItems.Count -lt $originalCount) {
                            # Update DIR.TAG
                            $params = @{
                                DirectoryPath = $dir
                                TodoItems = $todoItems
                                Force = $Force
                            }

                            $updateResult = Update-DirTag @params
                            $result.Success = $updateResult.Success
                            $result.Message = "Removed todo item from $dir"
                        }
                        else {
                            $result.Success = $true
                            $result.Message = "Todo item not found in $dir"
                        }
                    }
                    else {
                        $result.Message = "DIR.TAG not found in $dir"
                    }
                }

                ([DirTagGroupOperation]::Update) {
                    if (-not $TodoItem) {
                        $result.Message = "TodoItem parameter is required for Update operation"
                        break
                    }

                    $dirTagPath = Join-Path -Path $dir -ChildPath "DIR.TAG"

                    if (Test-Path $dirTagPath) {
                        # Read existing content
                        $content = Get-Content -Path $dirTagPath -Raw

                        # Extract existing TODO items
                        $todoItems = @()
                        if ($content -match '#TODO:\s*\n((?:\s*-\s*.+\n)+)') {
                            $todoItems = $matches[1] -split "`n" |
                                Where-Object { $_ -match '\s*-\s*(.+)' } |
                                ForEach-Object { $matches[1].Trim() }
                        }

                        # Replace status in the todo item or add if not exists
                        $found = $false
                        for ($i = 0; $i -lt $todoItems.Count; $i++) {
                            if ($todoItems[$i] -match '(.+?)\s*\[.+?\](.*)') {
                                $prefix = $matches[1]
                                $suffix = $matches[2]

                                # If we find the matching item (ignoring status)
                                if ($TodoItem -match [regex]::Escape($prefix)) {
                                    $todoItems[$i] = "$prefix [$Status]$suffix"
                                    $found = $true
                                    break
                                }
                            }
                        }

                        if (-not $found) {
                            # Add new item with status
                            $todoItems += "$TodoItem [$Status]"
                        }

                        # Update DIR.TAG
                        $params = @{
                            DirectoryPath = $dir
                            TodoItems = $todoItems
                            Force = $Force
                        }

                        $updateResult = Update-DirTag @params
                        $result.Success = $updateResult.Success
                        $result.Message = if ($found) { "Updated todo item in $dir" } else { "Added new todo item with status in $dir" }
                    }
                    else {
                        # Create new DIR.TAG with the item
                        $params = @{
                            DirectoryPath = $dir
                            TodoItems = @("$TodoItem [$Status]")
                            Force = $Force
                        }

                        $newResult = New-DirTag @params
                        $result.Success = $newResult
                        $result.Message = "Created new DIR.TAG with todo item in $dir"
                    }
                }

                ([DirTagGroupOperation]::SetStatus) {
                    if (-not $Status) {
                        $result.Message = "Status parameter is required for SetStatus operation"
                        break
                    }

                    $params = @{
                        DirectoryPath = $dir
                        Status = $Status
                        Force = $Force
                    }

                    $updateResult = Update-DirTag @params
                    $result.Success = $updateResult.Success
                    $result.Message = "Set status to $Status in $dir"
                }

                ([DirTagGroupOperation]::Validate) {
                    $validationResult = Test-DirTag -DirectoryPath $dir -Detailed
                    $result.Success = $validationResult.Valid
                    $result.Message = if ($validationResult.Valid) {
                        "DIR.TAG is valid in $dir"
                    } else {
                        "DIR.TAG validation failed in $dir: $($validationResult.Issues -join ', ')"
                    }
                }

                ([DirTagGroupOperation]::Propagate) {
                    if (-not $TodoItem) {
                        $result.Message = "TodoItem parameter is required for Propagate operation"
                        break
                    }

                    # For propagation, we need to find all subdirectories
                    $subdirs = Get-ChildItem -Path $dir -Directory -Recurse

                    foreach ($subdir in $subdirs) {
                        $subdirResult = Invoke-DirTagGroupOperation -Group (New-DirTagGroup -Name "TempSub" -DirectoryPaths @($subdir.FullName)) -Operation ([DirTagGroupOperation]::Add) -TodoItem $TodoItem -Force:$Force

                        if (-not $subdirResult[0].Success) {
                            $result.Success = $false
                            $result.Message = "Failed to propagate to $($subdir.FullName): $($subdirResult[0].Message)"
                            break
                        }
                    }

                    # Add to the current directory too
                    $currentResult = Invoke-DirTagGroupOperation -Group (New-DirTagGroup -Name "TempCurrent" -DirectoryPaths @($dir)) -Operation ([DirTagGroupOperation]::Add) -TodoItem $TodoItem -Force:$Force

                    $result.Success = $currentResult[0].Success
                    $result.Message = "Propagated todo item to $dir and subdirectories"
                }

                ([DirTagGroupOperation]::Reorganize) {
                    $dirTagPath = Join-Path -Path $dir -ChildPath "DIR.TAG"

                    if (Test-Path $dirTagPath) {
                        # Read existing content
                        $content = Get-Content -Path $dirTagPath -Raw

                        # Extract existing TODO items
                        $todoItems = @()
                        if ($content -match '#TODO:\s*\n((?:\s*-\s*.+\n)+)') {
                            $todoItems = $matches[1] -split "`n" |
                                Where-Object { $_ -match '\s*-\s*(.+)' } |
                                ForEach-Object { $matches[1].Trim() }
                        }

                        # Reorganize based on status
                        $done = @()
                        $partial = @()
                        $outstanding = @()
                        $noStatus = @()

                        foreach ($item in $todoItems) {
                            if ($item -match '\[DONE\]') {
                                $done += $item
                            }
                            elseif ($item -match '\[PARTIALLY_COMPLETE\]') {
                                $partial += $item
                            }
                            elseif ($item -match '\[OUTSTANDING\]') {
                                $outstanding += $item
                            }
                            else {
                                $noStatus += $item
                            }
                        }

                        # Create reorganized list with outstanding first, then partial, then done
                        $reorganized = $outstanding + $noStatus + $partial + $done

                        # Update DIR.TAG
                        $params = @{
                            DirectoryPath = $dir
                            TodoItems = $reorganized
                            Force = $Force
                        }

                        $updateResult = Update-DirTag @params
                        $result.Success = $updateResult.Success
                        $result.Message = "Reorganized todo items in $dir"
                    }
                    else {
                        $result.Message = "DIR.TAG not found in $dir"
                    }
                }

                ([DirTagGroupOperation]::Sync) {
                    # This operation syncs GPU-related tasks across related directories
                    # First, get all GPU-related tasks from all DIR.TAG files
                    $gpuTasks = @()
                    $allDirTags = Find-DirTags -RootPath "c:\Projects\autogen" -IncludeContent

                    foreach ($tag in $allDirTags) {
                        if ($tag.Content -match '#TODO:\s*\n((?:\s*-\s*.+\n)+)') {
                            $todoItems = $matches[1] -split "`n" |
                                Where-Object { $_ -match '\s*-\s*(.+)' } |
                                ForEach-Object { $matches[1].Trim() }

                            # Find GPU-related tasks
                            $gpuItems = $todoItems | Where-Object { $_ -match 'GPU|NVIDIA|CUDA' }

                            foreach ($item in $gpuItems) {
                                if (-not ($gpuTasks -contains $item)) {
                                    $gpuTasks += $item
                                }
                            }
                        }
                    }

                    # Now add these GPU tasks to the current directory
                    $dirTagPath = Join-Path -Path $dir -ChildPath "DIR.TAG"

                    if (Test-Path $dirTagPath) {
                        # Read existing content
                        $content = Get-Content -Path $dirTagPath -Raw

                        # Extract existing TODO items
                        $todoItems = @()
                        if ($content -match '#TODO:\s*\n((?:\s*-\s*.+\n)+)') {
                            $todoItems = $matches[1] -split "`n" |
                                Where-Object { $_ -match '\s*-\s*(.+)' } |
                                ForEach-Object { $matches[1].Trim() }
                        }

                        # Add GPU tasks that don't already exist
                        $addedCount = 0
                        foreach ($gpuTask in $gpuTasks) {
                            if (-not ($todoItems -contains $gpuTask)) {
                                $todoItems += $gpuTask
                                $addedCount++
                            }
                        }

                        if ($addedCount -gt 0) {
                            # Update DIR.TAG
                            $params = @{
                                DirectoryPath = $dir
                                TodoItems = $todoItems
                                Force = $Force
                            }

                            $updateResult = Update-DirTag @params
                            $result.Success = $updateResult.Success
                            $result.Message = "Added $addedCount GPU-related tasks to $dir"
                        }
                        else {
                            $result.Success = $true
                            $result.Message = "No new GPU tasks to add to $dir"
                        }
                    }
                    else {
                        # Create new DIR.TAG with the GPU tasks
                        $params = @{
                            DirectoryPath = $dir
                            TodoItems = $gpuTasks
                            Force = $Force
                        }

                        $newResult = New-DirTag @params
                        $result.Success = $newResult
                        $result.Message = "Created new DIR.TAG with GPU tasks in $dir"
                    }
                }
            }
        }
        catch {
            $result.Success = $false
            $result.Message = "Error: $_"
        }

        $results += $result
    }

    return $results
}

function Sync-GPURelatedDirTags {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )

    $gpuGroup = Get-GPUConfigurationDirTagGroup
    $result = Invoke-DirTagGroupOperation -Group $gpuGroup -Operation ([DirTagGroupOperation]::Sync) -Force:$Force -WhatIf:$WhatIf

    return $result
}

function Add-GPUTaskToDirTags {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TaskDescription,

        [Parameter(Mandatory = $false)]
        [string]$Status = "OUTSTANDING",

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )

    $gpuGroup = Get-GPUConfigurationDirTagGroup

    # Format the task with status if not already formatted
    if ($TaskDescription -notmatch '\[.+?\]') {
        $TaskDescription = "$TaskDescription [$Status]"
    }

    $result = Invoke-DirTagGroupOperation -Group $gpuGroup -Operation ([DirTagGroupOperation]::Add) -TodoItem $TaskDescription -Force:$Force -WhatIf:$WhatIf

    return $result
}

function Update-GPUTaskStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TaskDescription,

        [Parameter(Mandatory = $true)]
        [ValidateSet("DONE", "PARTIALLY_COMPLETE", "OUTSTANDING")]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )

    $gpuGroup = Get-GPUConfigurationDirTagGroup
    $result = Invoke-DirTagGroupOperation -Group $gpuGroup -Operation ([DirTagGroupOperation]::Update) -TodoItem $TaskDescription -Status $Status -Force:$Force -WhatIf:$WhatIf

    return $result
}

function Remove-GPUTaskFromDirTags {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TaskDescription,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )

    $gpuGroup = Get-GPUConfigurationDirTagGroup
    $result = Invoke-DirTagGroupOperation -Group $gpuGroup -Operation ([DirTagGroupOperation]::Remove) -TodoItem $TaskDescription -Force:$Force -WhatIf:$WhatIf

    return $result
}

function Test-GPUDirTags {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )

    $gpuGroup = Get-GPUConfigurationDirTagGroup
    $result = Invoke-DirTagGroupOperation -Group $gpuGroup -Operation ([DirTagGroupOperation]::Validate)

    if (-not $Detailed) {
        return $result | ForEach-Object { $_.Success }
    }

    return $result
}

function Get-StdDirTagGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("DevContainer", "Toolbox", "Docker", "Swarm", "BuildKit", "All", "Smoll2")]
        [string]$GroupName
    )

    switch ($GroupName) {
        "DevContainer" {
            return New-DirTagGroup -Name "DevContainer" -Description "DevContainer configuration files" -DirectoryPaths @(
                ".devcontainer"
            ) -DirectoryPatterns @(
                ".devcontainer/*"
            ) -ExcludePatterns @('node_modules', '.git', 'bin', 'obj')
        }
        "Toolbox" {
            return New-DirTagGroup -Name "Toolbox" -Description "Toolbox utilities and modules" -DirectoryPaths @(
                ".toolbox",
                ".toolbox/modules",
                ".toolbox/docker"
            )
        }
        "Docker" {
            return New-DirTagGroup -Name "Docker" -Description "Docker configuration files" -DirectoryPaths @(
                ".devcontainer/docker",
                ".toolbox/docker"
            ) -DirectoryPatterns @(
                "**/*docker*"
            )
        }
        "Swarm" {
            return New-DirTagGroup -Name "Swarm" -Description "Docker Swarm configuration files" -DirectoryPaths @(
                ".devcontainer/swarm",
                ".devcontainer/swarm/utils",
                ".devcontainer/swarm/sidecar-containers",
                ".toolbox/docker/swarm-compose"
            )
        }
        "BuildKit" {
            return New-DirTagGroup -Name "BuildKit" -Description "BuildKit configuration files" -DirectoryPaths @(
                ".devcontainer/buildkit"
            )
        }
        "Smoll2" {
            return New-DirTagGroup -Name "Smoll2" -Description "smoll2 LLM configuration files" -DirectoryPaths @(
                ".devcontainer/docker",
                ".devcontainer/swarm",
                ".toolbox/docker",
                "docs"
            ) -Tags "smoll2,LLM,Performance,RAMDisk"
        }
        "All" {
            return New-DirTagGroup -Name "All" -Description "All DIR.TAG files" -DirectoryPatterns @(
                "**"
            ) -ExcludePatterns @('node_modules', '.git', 'bin', 'obj', 'packages')
        }
    }
}

function Get-Smoll2ConfigurationDirTagGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$IncludeDocumentation,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeTestFiles
    )

    # Create a group for Smoll2-related DIR.TAG files with relative paths
    $group = New-DirTagGroup -Name "Smoll2Configuration" -Description "DIR.TAG files related to Smoll2 LLM configuration and optimizations"

    # Add common Smoll2-related directories
    $group.AddDirectory(".devcontainer")
    $group.AddDirectory(".devcontainer/swarm")
    $group.AddDirectory(".devcontainer/docker")
    $group.AddDirectory(".toolbox/docker")
    $group.AddDirectory(".toolbox/docker/swarm-compose")
    $group.AddDirectory(".toolbox/modules")

    # Add Smoll2-specific directories
    $group.AddDirectory(".devcontainer/ramdisk")
    $group.AddDirectory(".devcontainer/models")

    # Add pattern for any Smoll2-related directories
    $group.AddDirectoryPattern("**/*smoll*")
    $group.AddDirectoryPattern("**/*llm*")
    $group.AddDirectoryPattern("**/*ramdisk*")

    # Optionally include documentation
    if ($IncludeDocumentation) {
        $group.AddDirectory("docs")
        $group.AddDirectory(".github/workflows")
        $group.AddDirectoryPattern("**/*smoll*.md")
    }

    # Optionally include test files
    if ($IncludeTestFiles) {
        $group.AddDirectory("tests")
        $group.AddDirectoryPattern("**/*test*.ps1")
        $group.AddDirectoryPattern("**/*benchmark*.ps1")
    }

    # Metadata for Smoll2 group
    $group.Metadata = @{
        Category = "AI/ML"
        Priority = "High"
        RelatedTech = @("Smoll2", "LLM", "RAMDisk", "Docker", "Swarm", "GPU", "CUDA", "PrecompiledFactory")
        PerformanceCategory = "Ultra-Low Latency"
        CacheStrategy = "RAM-First with Persistent Backup"
        ContainerOptimized = $true
    }

    return $group
}

function Sync-Smoll2RelatedDirTags {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$WhatIf,

        [Parameter(Mandatory = $false)]
        [ValidateSet("All", "Configuration", "Performance", "Documentation")]
        [string]$Category = "All",

        [Parameter(Mandatory = $false)]
        [switch]$IncludeDependencies
    )

    $startTime = Get-Date
    Write-Verbose "Starting Smoll2 DIR.TAG synchronization at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    # Get the Smoll2 configuration group
    $smoll2Group = Get-Smoll2ConfigurationDirTagGroup

    # Define standard Smoll2 tasks by category with containerization best practices
    $configurationTasks = @(
        "Configure Smoll2 LLM for Docker Model Runner [OUTSTANDING]",
        "Set up RAM disk mounting for Smoll2 model cache [OUTSTANDING]",
        "Configure Docker Swarm for optimal Smoll2 performance [OUTSTANDING]",
        "Pre-cache VS Code extensions (including Vim) for containerized development [OUTSTANDING]"
    )

    $performanceTasks = @(
        "Implement precompiled cache factory pattern for Smoll2 [OUTSTANDING]",
        "Optimize memory allocation for Smoll2 token processing [OUTSTANDING]",
        "Configure GPU passthrough for Smoll2 inference [OUTSTANDING]",
        "Set up performance benchmarking for Smoll2 with/without RAM disk [OUTSTANDING]",
        "Implement container-aware resource allocation detection [OUTSTANDING]"
    )

    $documentationTasks = @(
        "Document Smoll2 precompiled cached factory pattern [OUTSTANDING]",
        "Create usage examples for Smoll2 with RAM disk [OUTSTANDING]",
        "Document performance benchmarks and optimization strategies [OUTSTANDING]",
        "Document containerization best practices for extension pre-caching [OUTSTANDING]"
    )

    # Combine tasks based on selected category
    $tasksToSync = @()

    switch ($Category) {
        "All" {
            $tasksToSync += $configurationTasks
            $tasksToSync += $performanceTasks
            $tasksToSync += $documentationTasks
        }
        "Configuration" {
            $tasksToSync += $configurationTasks
        }
        "Performance" {
            $tasksToSync += $performanceTasks
        }
        "Documentation" {
            $tasksToSync += $documentationTasks
        }
    }

    # Add dependency tasks if requested
    if ($IncludeDependencies) {
        $dependencyTasks = @(
            "Set up NVIDIA Container Toolkit for GPU acceleration [OUTSTANDING]",
            "Configure Docker daemon.json for GPU passthrough [OUTSTANDING]",
            "Implement shared memory volumes for inter-container communication [OUTSTANDING]",
            "Create extension volume for VS Code extension sharing [OUTSTANDING]"
        )
        $tasksToSync += $dependencyTasks
    }

    $results = @()

    # Process each task
    foreach ($task in $tasksToSync) {
        try {
            $addResult = Invoke-DirTagGroupOperation -Group $smoll2Group -Operation ([DirTagGroupOperation]::Add) -TodoItem $task -Force:$Force -WhatIf:$WhatIf
            $results += $addResult

            Write-Verbose "Added task: $task to $($addResult.Count) directories"
        }
        catch {
            Write-Warning "Failed to add task: $task. Error: $_"
        }
    }

    # Set the overall status for DIR.TAG files
    try {
        $statusResult = Invoke-DirTagGroupOperation -Group $smoll2Group -Operation ([DirTagGroupOperation]::SetStatus) -Status "PARTIALLY_COMPLETE" -Force:$Force -WhatIf:$WhatIf
        $results += $statusResult
    }
    catch {
        Write-Warning "Failed to set status. Error: $_"
    }

    # Reorganize tasks
    try {
        $reorganizeResult = Invoke-DirTagGroupOperation -Group $smoll2Group -Operation ([DirTagGroupOperation]::Reorganize) -Force:$Force -WhatIf:$WhatIf
        $results += $reorganizeResult
    }
    catch {
        Write-Warning "Failed to reorganize tasks. Error: $_"
    }

    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    Write-Verbose "Completed Smoll2 DIR.TAG synchronization in $([Math]::Round($duration, 2)) seconds"

    # Prepare summary
    $summary = @{
        Category = $Category
        TasksProcessed = $tasksToSync.Count
        DirectoriesUpdated = ($results | Where-Object { $_.Success -eq $true } | Select-Object -ExpandProperty Directory -Unique).Count
        SuccessRate = [Math]::Round(($results | Where-Object { $_.Success -eq $true }).Count / $results.Count * 100, 2)
        ExecutionTime = [Math]::Round($duration, 2)
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        ContainerAware = $true
    }

    # Add summary as note to the results
    $results | Add-Member -NotePropertyName Summary -NotePropertyValue $summary

    return $results
}

function Update-Smoll2PrecompiledCachedFactoryTasks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            "RAM_DISK_SETUP", "MODEL_COMPILATION", "CACHE_CONFIGURATION",
            "GPU_OPTIMIZATION", "BENCHMARK", "DOCUMENTATION",
            "CONTAINER_OPTIMIZATION", "EXTENSION_PRECACHING", "ALL"
        )]
        [string]$Component,

        [Parameter(Mandatory = $true)]
        [ValidateSet("NOT_STARTED", "PARTIALLY_COMPLETE", "DONE", "OUTSTANDING")]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )

    # Get the Smoll2 configuration group
    $smoll2Group = Get-Smoll2ConfigurationDirTagGroup

    # Define tasks by component with container best practices
    $componentTasks = @{
        RAM_DISK_SETUP = @(
            "Set up RAM disk mounting for Smoll2 model cache",
            "Configure tmpfs for Docker volumes",
            "Implement RAM disk performance monitoring"
        )
        MODEL_COMPILATION = @(
            "Implement precompiled cache factory pattern for Smoll2",
            "Create model compilation pipeline",
            "Set up CI/CD job for model precompilation"
        )
        CACHE_CONFIGURATION = @(
            "Configure caching layers for Smoll2 LLM",
            "Implement cache invalidation strategy",
            "Set up persistent backup for RAM-based cache"
        )
        GPU_OPTIMIZATION = @(
            "Configure GPU passthrough for Smoll2 inference",
            "Optimize CUDA operations for token generation",
            "Implement mixed precision inference"
        )
        BENCHMARK = @(
            "Set up performance benchmarking for Smoll2 with/without RAM disk",
            "Create latency comparison tests",
            "Implement throughput measurement tools"
        )
        DOCUMENTATION = @(
            "Document Smoll2 precompiled cached factory pattern",
            "Create usage examples for Smoll2 with RAM disk",
            "Document performance benchmarks and optimization strategies"
        )
        CONTAINER_OPTIMIZATION = @(
            "Optimize container image layers for Smoll2",
            "Implement container health checks for Smoll2 service",
            "Create multi-stage builds for smaller runtime images"
        )
        EXTENSION_PRECACHING = @(
            "Configure VS Code extension pre-caching",
            "Set up persistent extension volume",
            "Add Vim extension to pre-cached extensions",
            "Create post-create script for extension installation"
        )
    }

    # Determine which tasks to update
    $tasksToUpdate = @()
    if ($Component -eq "ALL") {
        foreach ($comp in $componentTasks.Keys) {
            $tasksToUpdate += $componentTasks[$comp]
        }
    }
    else {
        $tasksToUpdate = $componentTasks[$Component]
    }

    if (-not $tasksToUpdate -or $tasksToUpdate.Count -eq 0) {
        Write-Warning "No tasks found for component: $Component"
        return $null
    }

    Write-Verbose "Updating $($tasksToUpdate.Count) tasks for component: $Component with status: $Status"

    $results = @()

    # Update status for each task
    foreach ($task in $tasksToUpdate) {
        try {
            $updateResult = Invoke-DirTagGroupOperation -Group $smoll2Group -Operation ([DirTagGroupOperation]::Update) -TodoItem $task -Status $Status -Force:$Force -WhatIf:$WhatIf
            $results += $updateResult

            Write-Verbose "Updated task: '$task' with status: $Status in $($updateResult.Count) directories"
        }
        catch {
            Write-Warning "Failed to update task: '$task'. Error: $_"
        }
    }

    # Calculate success metrics
    $successCount = ($results | Where-Object { $_.Success -eq $true }).Count
    $totalOperations = $results.Count
    $successRate = if ($totalOperations -gt 0) { [Math]::Round(($successCount / $totalOperations) * 100, 1) } else { 0 }

    # Create a summary object
    $updateSummary = [PSCustomObject]@{
        Component = $Component
        Status = $Status
        TasksUpdated = $tasksToUpdate.Count
        DirectoriesProcessed = ($results | Select-Object -ExpandProperty Directory -Unique).Count
        SuccessCount = $successCount
        TotalOperations = $totalOperations
        SuccessRate = $successRate
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        ContainerAware = $true
    }

    Write-Verbose "Update summary: $($updateSummary | ConvertTo-Json -Compress)"

    # Add summary to the results
    $results | Add-Member -NotePropertyName Summary -NotePropertyValue $updateSummary -Force

    return $results
}

# Export module members
Export-ModuleMember -Function New-DirTagGroup, Get-GPUConfigurationDirTagGroup, Invoke-DirTagGroupOperation,
                             Sync-GPURelatedDirTags, Add-GPUTaskToDirTags, Update-GPUTaskStatus,
                             Remove-GPUTaskFromDirTags, Test-GPUDirTags, Get-StdDirTagGroup,
                             Get-Smoll2ConfigurationDirTagGroup, Sync-Smoll2RelatedDirTags,
                             Update-Smoll2PrecompiledCachedFactoryTasks

# Example: Add extension pre-caching task to all relevant DIR.TAGs
function Add-ExtensionPrecacheTaskToDirTags {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    $task = "Pre-cache VS Code extensions (including Vim) for containerized development [OUTSTANDING]"
    $groups = @(
        Get-StdDirTagGroup -GroupName "DevContainer",
        Get-StdDirTagGroup -GroupName "Docker",
        Get-StdDirTagGroup -GroupName "Toolbox"
    )
    foreach ($group in $groups) {
        Invoke-DirTagGroupOperation -Group $group -Operation ([DirTagGroupOperation]::Add) -TodoItem $task -Force:$Force
    }
}
