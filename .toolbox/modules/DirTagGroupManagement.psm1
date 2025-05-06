# PowerShell module for centralized DIR.TAG group management
# Supports batch operations on DIR.TAG files across multiple directories

#Requires -Version 5.1

# Ensure compatibility with existing DirTagManagement module
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "DirTagManagement.psm1") -Force

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
        if (-not ($this.DirectoryPaths -contains $path)) {
            $this.DirectoryPaths += $path
        }
    }

    [void]AddDirectoryPattern([string]$pattern) {
        if (-not ($this.DirectoryPatterns -contains $pattern)) {
            $this.DirectoryPatterns += $pattern
        }
    }

    [void]AddExcludePattern([string]$pattern) {
        if (-not ($this.ExcludePatterns -contains $pattern)) {
            $this.ExcludePatterns += $pattern
        }
    }

    [string[]]ResolveDirectories() {
        $allDirs = @()

        # Add explicitly specified directories
        foreach ($dir in $this.DirectoryPaths) {
            if (Test-Path -Path $dir -PathType Container) {
                $allDirs += $dir
            }
        }

        # Add directories matching patterns
        foreach ($pattern in $this.DirectoryPatterns) {
            $dirs = Get-ChildItem -Path $pattern -Directory -Recurse:$this.IncludeSubdirectories |
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
        [switch]$IncludeSubdirectories,

        [Parameter(Mandatory = $false)]
        [hashtable]$Metadata = @{}
    )

    $group = [DirTagGroup]::new($Name)
    $group.Description = $Description
    $group.DirectoryPaths = $DirectoryPaths
    $group.DirectoryPatterns = $DirectoryPatterns
    $group.ExcludePatterns = $ExcludePatterns
    $group.IncludeSubdirectories = $IncludeSubdirectories
    $group.Metadata = $Metadata

    return $group
}

function Get-GPUConfigurationDirTagGroup {
    [CmdletBinding()]
    param()

    # Create a group for GPU-related DIR.TAG files
    $group = New-DirTagGroup -Name "GPUConfiguration" -Description "DIR.TAG files related to GPU configuration and optimization"

    # Add common GPU-related directories
    $group.AddDirectory("c:\Projects\autogen\.devcontainer")
    $group.AddDirectory("c:\Projects\autogen\.devcontainer\swarm")
    $group.AddDirectory("c:\Projects\autogen\.devcontainer\buildkit")
    $group.AddDirectory("c:\Projects\autogen\.devcontainer\docker")
    $group.AddDirectory("c:\Projects\autogen\.toolbox\docker")
    $group.AddDirectory("c:\Projects\autogen\.toolbox\docker\swarm-compose")
    $group.AddDirectory("c:\Projects\autogen\.toolbox\modules")

    # Add pattern for any docker-related directories that might contain GPU configurations
    $group.AddDirectoryPattern("c:\Projects\autogen\**\*gpu*")
    $group.AddDirectoryPattern("c:\Projects\autogen\**\*nvidia*")

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
                "c:\Projects\autogen\.devcontainer"
            ) -DirectoryPatterns @(
                "c:\Projects\autogen\.devcontainer\*"
            ) -ExcludePatterns @('node_modules', '.git', 'bin', 'obj')
        }
        "Toolbox" {
            return New-DirTagGroup -Name "Toolbox" -Description "Toolbox utilities and modules" -DirectoryPaths @(
                "c:\Projects\autogen\.toolbox",
                "c:\Projects\autogen\.toolbox\modules",
                "c:\Projects\autogen\.toolbox\docker"
            )
        }
        "Docker" {
            return New-DirTagGroup -Name "Docker" -Description "Docker configuration files" -DirectoryPaths @(
                "c:\Projects\autogen\.devcontainer\docker",
                "c:\Projects\autogen\.toolbox\docker"
            ) -DirectoryPatterns @(
                "c:\Projects\autogen\**\*docker*"
            )
        }        "Swarm" {
            return New-DirTagGroup -Name "Swarm" -Description "Docker Swarm configuration files" -DirectoryPaths @(
                "c:\Projects\autogen\.devcontainer\swarm",
                "c:\Projects\autogen\.devcontainer\swarm\utils",
                "c:\Projects\autogen\.devcontainer\swarm\sidecar-containers",
                "c:\Projects\autogen\.toolbox\docker\swarm-compose"
            )
        }
        "BuildKit" {
            return New-DirTagGroup -Name "BuildKit" -Description "BuildKit configuration files" -DirectoryPaths @(
                "c:\Projects\autogen\.devcontainer\buildkit"
            )
        }
        "Smoll2" {
            return New-DirTagGroup -Name "Smoll2" -Description "smoll2 LLM configuration files" -DirectoryPaths @(
                "c:\Projects\autogen\.devcontainer\docker",
                "c:\Projects\autogen\.devcontainer\swarm",
                "c:\Projects\autogen\.toolbox\docker",
                "c:\Projects\autogen\docs"
            ) -Tags "smoll2,LLM,Performance,RAMDisk"
        }
        "All" {
            return New-DirTagGroup -Name "All" -Description "All DIR.TAG files" -DirectoryPatterns @(
                "c:\Projects\autogen\**"
            ) -ExcludePatterns @('node_modules', '.git', 'bin', 'obj', 'packages')
        }
    }
}

# Export module members
Export-ModuleMember -Function New-DirTagGroup, Get-GPUConfigurationDirTagGroup, Invoke-DirTagGroupOperation,
                             Sync-GPURelatedDirTags, Add-GPUTaskToDirTags, Update-GPUTaskStatus,
                             Remove-GPUTaskFromDirTags, Test-GPUDirTags, Get-StdDirTagGroup,
                             Get-Smoll2ConfigurationDirTagGroup, Sync-Smoll2RelatedDirTags,
                             Update-Smoll2PrecompiledCachedFactoryTasks
