# Updated Update-DirTag function with round-robin processing and improved error handling
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
        [int]$RetryDelayMs = 250,

        [Parameter(Mandatory = $false)]
        [int]$ResourceOverheadPercent = 10
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
    }

    # Create a new DIR.TAG if it doesn't exist
    if (-not (Test-Path -Path $tagFilePath)) {
        Write-Verbose "DIR.TAG not found at $tagFilePath. Creating a new one."
        $params = @{
            DirectoryPath = $DirectoryPath
        }

        if ($PSBoundParameters.ContainsKey('Status')) { $params.Status = $Status }
        if ($PSBoundParameters.ContainsKey('Description')) { $params.Description = $Description }
        if ($PSBoundParameters.ContainsKey('TodoItems')) { $params.TodoItems = $TodoItems }
        if ($PSBoundParameters.ContainsKey('Force')) { $params.Force = $Force }

        $newTagResult = New-DirTag @params
        if (-not $newTagResult) {
            $result.StatusCode = [DirTagStatusCode]::ProcessingFailed
            $result.Message = "Failed to create new DIR.TAG at $tagFilePath"
            $result.Success = $false
            Write-Error $result.Message
            return $result
        }

        $result.Success = $true
        $result.Message = "Successfully created new DIR.TAG at $tagFilePath"
        return $result
    }

    # Implement sequential round-robin processing with retries
    $retryCount = 0
    $processed = $false
    $lastError = $null

    while (-not $processed -and $retryCount -lt $MaxRetries) {
        try {
            # Read the existing DIR.TAG file with retry logic in case of contention
            $content = $null
            try {
                $content = Get-Content -Path $tagFilePath -Raw -ErrorAction Stop
            }
            catch {
                # Handle file access issues with exponential backoff
                $retryCount++
                $delay = $RetryDelayMs * [Math]::Pow(2, $retryCount - 1)
                Write-Verbose "Failed to read DIR.TAG file, retry $retryCount/$MaxRetries after $delay ms"
                Start-Sleep -Milliseconds $delay
                continue
            }

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

            # Add resource overhead percentage to ensure stability
            $memoryOverhead = [Math]::Floor((Get-Process -Id $PID).WorkingSet64 * ($ResourceOverheadPercent / 100))

            # Create updated content
            $updatedContent = @"
#INDEX: $relativePath
#GUID: $guid
$todoFormatted
status: $Status
updated: $currentDate
description: |
  $Description
"@

            # Write the content to the DIR.TAG file
            try {
                # If Force is not specified, check if the file should be updated
                if (-not $Force) {
                    # Verify the file exists and compare with current content
                    if (Test-Path -Path $tagFilePath) {
                        $existingContent = Get-Content -Path $tagFilePath -Raw
                        # If content is the same, no need to update
                        if ($existingContent.Trim() -eq $updatedContent.Trim()) {
                            Write-Verbose "DIR.TAG at $tagFilePath is already up to date"
                            $result.StatusCode = [DirTagStatusCode]::Success
                            $result.Message = "DIR.TAG is already up-to-date"
                            $result.Success = $true
                            $processed = $true
                            break
                        }
                    }
                }

                # Update the file
                $updatedContent | Set-Content -Path $tagFilePath -Force
                Write-Verbose "Updated DIR.TAG at $tagFilePath"
                $result.StatusCode = [DirTagStatusCode]::Success
                $result.Message = "Updated DIR.TAG successfully"
                $result.Success = $true
                $processed = $true
            }
            catch {
                $lastError = $_
                $retryCount++
                $delay = $RetryDelayMs * [Math]::Pow(2, $retryCount - 1)
                Write-Verbose "Failed to write DIR.TAG file, retry $retryCount/$MaxRetries after $delay ms: $_"
                Start-Sleep -Milliseconds $delay
            }
        }
        catch {
            $lastError = $_
            $retryCount++
            $delay = $RetryDelayMs * [Math]::Pow(2, $retryCount - 1)
            Write-Verbose "Error processing DIR.TAG file, retry $retryCount/$MaxRetries after $delay ms: $_"
            Start-Sleep -Milliseconds $delay
        }
    }

    # If we couldn't process the file after all retries
    if (-not $processed) {
        $result.StatusCode = [DirTagStatusCode]::ProcessingFailed
        $result.Message = "Failed to update DIR.TAG after $MaxRetries attempts: $lastError"
        $result.Success = $false
        Write-Error $result.Message
    }

    return $result
}
