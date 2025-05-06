# PowerShell module for managing problems and integrating with DIR.TAG files

function Get-ProblemConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = (Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath ".config\dir-tag\dir-tag-config.xml")
    )

    if (-not (Test-Path -Path $ConfigPath)) {
        Write-Warning "Problem configuration file not found at $ConfigPath"
        return $null
    }

    try {
        [xml]$config = Get-Content -Path $ConfigPath -Raw
        return $config.dir_tag_configuration.problem_mapping
    }
    catch {
        Write-Error "Failed to parse problem configuration: $_"
        return $null
    }
}

function Get-DirectoryProblems {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,

        [Parameter(Mandatory = $false)]
        [string]$ProblemTypesFilter
    )

    # Check if directory exists
    if (-not (Test-Path -Path $DirectoryPath -PathType Container)) {
        Write-Warning "Directory not found: $DirectoryPath"
        return @()
    }

    # Get all files in the directory (recursively)
    $files = Get-ChildItem -Path $DirectoryPath -Recurse -File

    $problems = @()

    foreach ($file in $files) {
        # Skip certain file types
        if ($file.Extension -in @('.exe', '.dll', '.pdb', '.obj', '.bin')) {
            continue
        }

        # Check for problems based on file type
        switch -Regex ($file.Extension) {
            # PowerShell files
            '\.ps1|\.psm1' {
                $scriptProblems = Get-PowerShellProblems -FilePath $file.FullName
                $problems += $scriptProblems
            }
            # C# files
            '\.cs' {
                $csharpProblems = Get-CSharpProblems -FilePath $file.FullName
                $problems += $csharpProblems
            }
            # Python files
            '\.py' {
                $pythonProblems = Get-PythonProblems -FilePath $file.FullName
                $problems += $pythonProblems
            }
            # Markdown files
            '\.md' {
                $markdownProblems = Get-MarkdownProblems -FilePath $file.FullName
                $problems += $markdownProblems
            }
            # Default for other file types
            default {
                $genericProblems = Get-GenericFileProblems -FilePath $file.FullName
                $problems += $genericProblems
            }
        }
    }

    # Filter by problem type if specified
    if ($ProblemTypesFilter) {
        $problems = $problems | Where-Object { $_.Type -match $ProblemTypesFilter }
    }

    return $problems
}

function Get-PowerShellProblems {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $problems = @()

    try {
        # Use PSScriptAnalyzer if available
        if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
            $scriptAnalyzerProblems = Invoke-ScriptAnalyzer -Path $FilePath -WarningAction SilentlyContinue

            foreach ($problem in $scriptAnalyzerProblems) {
                $problems += [PSCustomObject]@{
                    FilePath = $FilePath
                    Line = $problem.Line
                    Column = $problem.Column
                    Type = switch ($problem.Severity) {
                        'Error' { 'error' }
                        'Warning' { 'warning' }
                        'Information' { 'info' }
                        default { 'info' }
                    }
                    Message = $problem.Message
                    RuleId = $problem.RuleName
                }
            }
        }
        else {            # Simple syntax check if PSScriptAnalyzer is not available
            $errors = $null
            $tokens = $null
            $parseResult = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$tokens, [ref]$errors)

            foreach ($parseError in $errors) {
                $problems += [PSCustomObject]@{
                    FilePath = $FilePath
                    Line = $parseError.Extent.StartLineNumber
                    Column = $parseError.Extent.StartColumnNumber
                    Type = 'error'
                    Message = $parseError.Message
                    RuleId = 'SyntaxError'
                }
            }
        }
    }
    catch {
        $problems += [PSCustomObject]@{
            FilePath = $FilePath
            Line = 0
            Column = 0
            Type = 'error'
            Message = "Failed to analyze file: $_"
            RuleId = 'AnalysisError'
        }
    }

    return $problems
}

function Get-CSharpProblems {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # This is a placeholder - in a real implementation, you might call
    # a C# analyzer or parse compiler output
    return @()
}

function Get-PythonProblems {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # This is a placeholder - in a real implementation, you might call
    # flake8, pylint, or another Python linter
    return @()
}

function Get-MarkdownProblems {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # This is a placeholder - in a real implementation, you might call
    # markdownlint or another Markdown linter
    return @()
}

function Get-GenericFileProblems {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # Check for basic problems like file size, encoding issues, etc.
    $problems = @()

    # Check file size
    $fileInfo = Get-Item -Path $FilePath
    if ($fileInfo.Length -gt 10MB) {
        $problems += [PSCustomObject]@{
            FilePath = $FilePath
            Line = 0
            Column = 0
            Type = 'warning'
            Message = "File size is large: $([Math]::Round($fileInfo.Length / 1MB, 2)) MB"
            RuleId = 'FileSizeWarning'
        }
    }

    # Check for trailing whitespace or BOM issues
    try {
        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop

        if ($content -match "\r\n" -and $content -match "\n[^\r]") {
            $problems += [PSCustomObject]@{
                FilePath = $FilePath
                Line = 0
                Column = 0
                Type = 'warning'
                Message = "File contains mixed line endings (CRLF and LF)"
                RuleId = 'MixedLineEndings'
            }
        }

        if ($content -match "\s+$") {
            $problems += [PSCustomObject]@{
                FilePath = $FilePath
                Line = 0
                Column = 0
                Type = 'info'
                Message = "File contains trailing whitespace"
                RuleId = 'TrailingWhitespace'
            }
        }
    }
    catch {
        $problems += [PSCustomObject]@{
            FilePath = $FilePath
            Line = 0
            Column = 0
            Type = 'error'
            Message = "Failed to analyze file: $_"
            RuleId = 'AnalysisError'
        }
    }

    return $problems
}

function Update-DirTagFromProblems {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # Import DirTagManagement module
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'DirTagManagement.psm1'
    if (-not (Test-Path $modulePath)) {
        Write-Error "DirTagManagement.psm1 not found at $modulePath"
        return $false
    }
    Import-Module $modulePath -Force

    # Get problems in the directory
    $problems = Get-DirectoryProblems -DirectoryPath $DirectoryPath

    if ($problems.Count -eq 0) {
        Write-Verbose "No problems found in $DirectoryPath"
        return $true
    }

    # Get problem configuration
    $problemConfig = Get-ProblemConfig
    if (-not $problemConfig) {
        Write-Warning "Problem configuration not found, using default mapping"
        $problemMapping = @{
            'error' = 'OUTSTANDING'
            'warning' = 'PARTIALLY_COMPLETE'
            'info' = 'NOT_STARTED'
        }
    }
    else {
        $problemMapping = @{}
        foreach ($type in $problemConfig.problem_type) {
            $problemMapping[$type.name] = $type.status
        }
    }

    # Determine the status based on the highest priority problem
    $status = 'DONE' # Default if no problems
    foreach ($priority in @('error', 'warning', 'info')) {
        if ($problems | Where-Object { $_.Type -eq $priority }) {
            $status = $problemMapping[$priority]
            break
        }
    }

    # Get current DIR.TAG content or create a new one
    $tagFilePath = Join-Path -Path $DirectoryPath -ChildPath "DIR.TAG"
    $todoItems = @()

    if (Test-Path $tagFilePath) {
        $content = Get-Content -Path $tagFilePath -Raw

        # Extract existing TODO items
        if ($content -match '#TODO:\s*\n((?:\s*-\s*.+\n)+)') {
            $todoItems = $matches[1] -split "`n" |
                Where-Object { $_ -match '\s*-\s*(.+)' } |
                ForEach-Object { $matches[1].Trim() }
        }

        # Append problem-related TODO items
        $problemsByType = $problems | Group-Object -Property Type
        foreach ($type in $problemsByType) {
            $todoItems += "Fix $($type.Count) $($type.Name) issues in directory [OUTSTANDING]"
        }        # Update the DIR.TAG
        $result = Update-DirTag -DirectoryPath $DirectoryPath -Status $status -TodoItems $todoItems -Force:$Force

        # Handle both boolean and object results for backward compatibility
        $isSuccess = Convert-DirTagResultToBool -Result $result

        if ($isSuccess) {
            Write-Verbose "Updated DIR.TAG in $DirectoryPath with problem information"

            # If it's a result object, log any messages
            if ($result.PSObject.Properties.Name -contains 'Message') {
                Write-Verbose $result.Message
            }

            return $true
        }
        else {
            $message = "Failed to update DIR.TAG in $DirectoryPath"

            # If it's a result object, include the error message
            if ($result.PSObject.Properties.Name -contains 'Message') {
                $message += ": $($result.Message)"
            }

            Write-Warning $message
            return $false
        }
    }
    else {
        # Append problem-related TODO items
        $problemsByType = $problems | Group-Object -Property Type
        foreach ($type in $problemsByType) {
            $todoItems += "Fix $($type.Count) $($type.Name) issues in directory [OUTSTANDING]"
        }

        # Create a new DIR.TAG
        $description = "Directory with $($problems.Count) identified problems"
        $result = New-DirTag -DirectoryPath $DirectoryPath -Status $status -Description $description -TodoItems $todoItems -Force:$Force

        if ($result) {
            Write-Verbose "Created DIR.TAG in $DirectoryPath with problem information"
            return $true
        }
        else {
            Write-Warning "Failed to create DIR.TAG in $DirectoryPath"
            return $false
        }
    }
}

# Add support for the enhanced Update-DirTag function
function Convert-DirTagResultToBool {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Result
    )

    process {
        # If it's already a boolean, return it
        if ($Result -is [bool]) {
            return $Result
        }

        # If it's a proper result object, check Success property
        if ($Result.PSObject.Properties.Name -contains 'Success') {
            return $Result.Success
        }

        # If it's a proper result object, check StatusCode property
        if ($Result.PSObject.Properties.Name -contains 'StatusCode') {
            return $Result.StatusCode -eq [DirTagStatusCode]::Success
        }

        # Default fallback to avoid runtime errors
        return $false
    }
}

# Export the functions
Export-ModuleMember -Function Get-ProblemConfig, Get-DirectoryProblems, Update-DirTagFromProblems
