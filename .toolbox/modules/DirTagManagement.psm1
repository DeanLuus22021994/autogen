# PowerShell module for managing DIR.TAG files across the project
# This complements the bash implementation at .devcontainer/manage-dir-tags.sh

function New-DirTag {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$DirectoryPath,

        [Parameter(Mandatory = $false)]
        [string]$Description = "",

        [Parameter(Mandatory = $false)]
        [string]$Status = "NOT_STARTED",

        [Parameter(Mandatory = $false)]
        [string[]]$TodoItems = @(
            "Implement configuration standards [OUTSTANDING]",
            "Document usage and schema [OUTSTANDING]",
            "Add integration tests [OUTSTANDING]"
        ),

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # Ensure the directory exists
    if (-not (Test-Path -Path $DirectoryPath -PathType Container)) {
        try {
            New-Item -Path $DirectoryPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Created directory: $DirectoryPath"
        }
        catch {
            Write-Error "Failed to create directory $DirectoryPath`: $_"
            return $false
        }
    }

    # Generate a new GUID for unique identification
    $guid = [System.Guid]::NewGuid().ToString()

    # Calculate the relative path from the repository root
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $repoRoot) {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        while (-not (Test-Path -Path (Join-Path -Path $repoRoot -ChildPath ".git")) -and $repoRoot -ne "") {
            $repoRoot = Split-Path -Path $repoRoot -Parent
        }
    }

    $relativePath = $DirectoryPath.Replace("$repoRoot\", "").Replace("\", "/")

    # Create or update the DIR.TAG file
    $tagFilePath = Join-Path -Path $DirectoryPath -ChildPath "DIR.TAG"

    if ((Test-Path -Path $tagFilePath) -and -not $Force) {
        Write-Warning "DIR.TAG already exists at $tagFilePath. Use -Force to overwrite."
        return $false
    }

    $currentDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

    # Format the TODO items
    $todoFormatted = "#TODO:`n"
    foreach ($item in $TodoItems) {
        $todoFormatted += "  - $item`n"
    }

    # Create the DIR.TAG content
    $content = @"
#INDEX: $relativePath
#GUID: $guid
$todoFormatted
status: $Status
updated: $currentDate
description: |
  $Description
"@

    # Create .gitkeep file to ensure empty directories are tracked
    $gitkeepPath = Join-Path -Path $DirectoryPath -ChildPath ".gitkeep"
    if (-not (Test-Path -Path $gitkeepPath)) {
        "" | Set-Content -Path $gitkeepPath -Force
        Write-Verbose "Created .gitkeep in $DirectoryPath"
    }

    # Write the content to the DIR.TAG file
    try {
        $content | Set-Content -Path $tagFilePath -Force
        Write-Verbose "Created/Updated DIR.TAG at $tagFilePath"
        return $true
    }
    catch {
        Write-Error "Failed to create DIR.TAG at $tagFilePath`: $_"
        return $false
    }
}

function Update-DirTag {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$DirectoryPath,

        [Parameter(Mandatory = $false)]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [string[]]$TodoItems,

        [Parameter(Mandatory = $false)]
        [switch]$PreserveGuid = $true,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelayMs = 250
    )

    # Initialize result object with status information
    $result = [PSCustomObject]@{
        StatusCode = [DirTagStatusCode]::Success
        Message = "Operation completed successfully"
        FilePath = $null
        Success = $false
        Data = $null
    }

    $tagFilePath = Join-Path -Path $DirectoryPath -ChildPath "DIR.TAG"
    $result.FilePath = $tagFilePath

    # Check if directory exists
    if (-not (Test-Path -Path $DirectoryPath -PathType Container)) {
        $result.StatusCode = [DirTagStatusCode]::DirectoryNotFound
        $result.Message = "Directory not found: $DirectoryPath"
        $result.Success = $false
        Write-Warning $result.Message
        return $result
    }if (-not (Test-Path -Path $tagFilePath)) {
        Write-Warning "DIR.TAG not found at $tagFilePath. Creating a new one."
        $params = @{
            DirectoryPath = $DirectoryPath
        }

        if ($PSBoundParameters.ContainsKey('Status')) { $params.Status = $Status }
        if ($PSBoundParameters.ContainsKey('Description')) { $params.Description = $Description }
        if ($PSBoundParameters.ContainsKey('TodoItems')) { $params.TodoItems = $TodoItems }
        if ($PSBoundParameters.ContainsKey('Force')) { $params.Force = $Force }

        return New-DirTag @params
    }

    # Read the existing DIR.TAG file
    $content = Get-Content -Path $tagFilePath -Raw

    # Extract the GUID if it exists and preserveGuid is true
    $guid = ""
    if ($PreserveGuid) {
        if ($content -match '#GUID:\s*([a-fA-F0-9-]+)') {
            $guid = $matches[1]
        }
    }

    if ($guid -eq "") {
        $guid = [System.Guid]::NewGuid().ToString()
    }

    # Calculate the relative path
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $repoRoot) {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        while (-not (Test-Path -Path (Join-Path -Path $repoRoot -ChildPath ".git")) -and $repoRoot -ne "") {
            $repoRoot = Split-Path -Path $repoRoot -Parent
        }
    }

    $relativePath = $DirectoryPath.Replace("$repoRoot\", "").Replace("\", "/")

    # Update timestamp
    $currentDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

    # Extract existing TODO items if not provided
    if (-not $PSBoundParameters.ContainsKey('TodoItems')) {
        $todoItems = @()
        if ($content -match '#TODO:\s*\n((?:\s*-\s*.+\n)+)') {
            $todoItems = $matches[1] -split "`n" |
                Where-Object { $_ -match '\s*-\s*(.+)' } |
                ForEach-Object { $matches[1].Trim() }
        }
    }

    # Format the TODO items
    $todoFormatted = "#TODO:`n"
    foreach ($item in $TodoItems) {
        $todoFormatted += "  - $item`n"
    }

    # Extract existing status or use provided one
    if (-not $PSBoundParameters.ContainsKey('Status')) {
        if ($content -match 'status:\s*([^\n]+)') {
            $Status = $matches[1]
        } else {
            $Status = "NOT_STARTED"
        }
    }

    # Extract existing description or use provided one
    if (-not $PSBoundParameters.ContainsKey('Description')) {
        if ($content -match 'description:\s*\|\s*\n((?:.+\n)+)') {
            $Description = $matches[1].Trim()
        } else {
            $Description = "Configuration directory for $relativePath"
        }
    }

    # Create updated content
    $updatedContent = @"
#INDEX: $relativePath
#GUID: $guid
$todoFormatted
status: $Status
updated: $currentDate
description: |
  $Description
"@    # Write the content to the DIR.TAG file
    try {
        # If Force is not specified, check if the file should be updated
        if (-not $Force) {
            # Verify the file exists and compare with current content
            if (Test-Path -Path $tagFilePath) {
                $existingContent = Get-Content -Path $tagFilePath -Raw
                # If content is the same, no need to update
                if ($existingContent.Trim() -eq $updatedContent.Trim()) {
                    Write-Verbose "DIR.TAG at $tagFilePath is already up to date"
                    return $true
                }
            }
        }

        # Update the file
        $updatedContent | Set-Content -Path $tagFilePath -Force
        Write-Verbose "Updated DIR.TAG at $tagFilePath"
        return $true
    }
    catch {
        Write-Error "Failed to update DIR.TAG at $tagFilePath`: $_"
        return $false
    }
}

function Test-DirTag {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$DirectoryPath,

        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )

    $tagFilePath = Join-Path -Path $DirectoryPath -ChildPath "DIR.TAG"
    $gitkeepPath = Join-Path -Path $DirectoryPath -ChildPath ".gitkeep"
    $issues = @()

    # Check if .gitkeep exists
    if (-not (Test-Path -Path $gitkeepPath)) {
        $issues += "Missing .gitkeep in $DirectoryPath"
    }

    # Check if DIR.TAG exists
    if (-not (Test-Path -Path $tagFilePath)) {
        $issues += "Missing DIR.TAG in $DirectoryPath"

        # No need to check further if the file doesn't exist
        if ($Detailed) {
            return [PSCustomObject]@{
                Path = $DirectoryPath
                Valid = $false
                Issues = $issues
                TagExists = $false
                Content = $null
            }
        } else {
            return $false
        }
    }

    # Read the DIR.TAG content
    $content = Get-Content -Path $tagFilePath -Raw

    # Check for required fields
    if (-not ($content -match '#INDEX:')) {
        $issues += "Missing #INDEX in $tagFilePath"
    }

    if (-not ($content -match '#GUID:')) {
        $issues += "Missing #GUID in $tagFilePath"
    }

    if (-not ($content -match '#TODO:')) {
        $issues += "Missing #TODO in $tagFilePath"
    }

    if (-not ($content -match 'status:')) {
        $issues += "Missing status in $tagFilePath"
    }

    if (-not ($content -match 'updated:')) {
        $issues += "Missing updated timestamp in $tagFilePath"
    }

    if (-not ($content -match 'description:')) {
        $issues += "Missing description in $tagFilePath"
    }

    # Check for correct index
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $repoRoot) {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        while (-not (Test-Path -Path (Join-Path -Path $repoRoot -ChildPath ".git")) -and $repoRoot -ne "") {
            $repoRoot = Split-Path -Path $repoRoot -Parent
        }
    }

    $relativePath = $DirectoryPath.Replace("$repoRoot\", "").Replace("\", "/")

    if ($content -match '#INDEX:\s*([^\n]+)') {
        $index = $matches[1].Trim()
        if ($index -ne $relativePath) {
            $issues += "Incorrect #INDEX in $tagFilePath (is: $index, should be: $relativePath)"
        }
    }

    # Return results
    if ($Detailed) {
        return [PSCustomObject]@{
            Path = $DirectoryPath
            Valid = ($issues.Count -eq 0)
            Issues = $issues
            TagExists = $true
            Content = $content
        }
    } else {
        return ($issues.Count -eq 0)
    }
}

function Find-DirTags {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$RootPath = (git rev-parse --show-toplevel 2>$null),

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludeFolders = @('.git', 'node_modules', 'bin', 'obj', 'packages'),

        [Parameter(Mandatory = $false)]
        [switch]$IncludeContent,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateAll
    )

    if (-not $RootPath) {
        $RootPath = Split-Path -Path $PSScriptRoot -Parent
        while (-not (Test-Path -Path (Join-Path -Path $RootPath -ChildPath ".git")) -and $RootPath -ne "") {
            $RootPath = Split-Path -Path $RootPath -Parent
        }

        if ($RootPath -eq "") {
            $RootPath = Get-Location
        }
    }

    $excludePattern = ($ExcludeFolders | ForEach-Object { [regex]::Escape($_) }) -join '|'

    # Find all DIR.TAG files
    $dirTagFiles = Get-ChildItem -Path $RootPath -Filter "DIR.TAG" -Recurse -File |
        Where-Object { $_.FullName -notmatch $excludePattern }

    $results = @()

    foreach ($file in $dirTagFiles) {
        $directory = Split-Path -Path $file.FullName -Parent

        $result = [PSCustomObject]@{
            Path = $directory
            File = $file.FullName
            RelativePath = (Resolve-Path -Path $directory -Relative).TrimStart('.\').Replace('\', '/')
        }

        if ($IncludeContent) {
            $result | Add-Member -MemberType NoteProperty -Name "Content" -Value (Get-Content -Path $file.FullName -Raw)
        }

        if ($ValidateAll) {
            $validation = Test-DirTag -DirectoryPath $directory -Detailed
            $result | Add-Member -MemberType NoteProperty -Name "Valid" -Value $validation.Valid
            $result | Add-Member -MemberType NoteProperty -Name "Issues" -Value $validation.Issues
        }

        $results += $result
    }

    return $results
}

# Define error/status codes for better monitoring and diagnostics
enum DirTagStatusCode {
    Success = 0
    FileNotFound = 1
    AccessDenied = 2
    InvalidContent = 3
    SyntaxError = 4
    DirectoryNotFound = 5
    ProcessingFailed = 6
    ValidationFailed = 7
    GeneralError = 99
}

function Get-DirTagStatusMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [DirTagStatusCode]$StatusCode
    )

    $statusMessages = @{
        [DirTagStatusCode]::Success = "Operation completed successfully"
        [DirTagStatusCode]::FileNotFound = "DIR.TAG file not found"
        [DirTagStatusCode]::AccessDenied = "Access denied to DIR.TAG file"
        [DirTagStatusCode]::InvalidContent = "Invalid DIR.TAG content format"
        [DirTagStatusCode]::SyntaxError = "Syntax error in DIR.TAG content"
        [DirTagStatusCode]::DirectoryNotFound = "Target directory not found"
        [DirTagStatusCode]::ProcessingFailed = "Processing failed"
        [DirTagStatusCode]::ValidationFailed = "Validation failed"
        [DirTagStatusCode]::GeneralError = "An unexpected error occurred"
    }

    return $statusMessages[$StatusCode]
}

# Export the functions
Export-ModuleMember -Function New-DirTag, Update-DirTag, Test-DirTag, Find-DirTags, Get-DirTag, Set-DirTag
