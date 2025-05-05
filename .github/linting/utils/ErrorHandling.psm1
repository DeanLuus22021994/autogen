# .github\linting\utils\ErrorHandling.psm1
# Error handling utilities for markdown linting

using namespace System.Management.Automation

<#
.SYNOPSIS
    Provides error handling utilities for markdown linting operations.
.DESCRIPTION
    A set of functions to standardize error handling, formatting, and reporting.
#>

function Get-FormattedErrorMessage {
    <#
    .SYNOPSIS
        Formats an error message with context.
    .DESCRIPTION
        Creates a standardized error message that includes the exception details
        and the context in which the error occurred.
    .PARAMETER ErrorRecord
        The PowerShell ErrorRecord to format.
    .PARAMETER Context
        A description of what operation was being performed when the error occurred.
    .OUTPUTS
        [string] Formatted error message
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter()]
        [string]$Context = "an operation"
    )

    $errorMessage = "Error during $Context`: "

    # Add exception message
    $errorMessage += $ErrorRecord.Exception.Message

    # Add position message if available
    if ($ErrorRecord.InvocationInfo.PositionMessage) {
        $positionMessage = $ErrorRecord.InvocationInfo.PositionMessage -split "`n" | Select-Object -First 1
        $errorMessage += " at $positionMessage"
    }

    # Add inner exception if available
    if ($ErrorRecord.Exception.InnerException) {
        $errorMessage += "`nInner error: " + $ErrorRecord.Exception.InnerException.Message
    }

    return $errorMessage
}

function Write-ErrorWithContext {
    <#
    .SYNOPSIS
        Writes an error message with context to the error stream.
    .DESCRIPTION
        Formats and outputs an error with additional context information
        to make debugging easier.
    .PARAMETER ErrorRecord
        The PowerShell ErrorRecord to write.
    .PARAMETER Context
        A description of what operation was being performed when the error occurred.
    .PARAMETER WriteWarning
        If set, writes as a warning instead of an error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter()]
        [string]$Context = "an operation",

        [Parameter()]
        [switch]$WriteWarning
    )

    $message = Get-FormattedErrorMessage -ErrorRecord $ErrorRecord -Context $Context

    if ($WriteWarning) {
        Write-Warning $message
    } else {
        Write-Error $message
    }
}

function New-ErrorRecord {
    <#
    .SYNOPSIS
        Creates a new ErrorRecord for standardized error reporting.
    .DESCRIPTION
        Generates a PowerShell ErrorRecord with consistent structure for
        error handling throughout the markdown linting code.
    .PARAMETER Exception
        The exception that occurred.
    .PARAMETER Category
        The error category.
    .PARAMETER ErrorId
        A unique identifier for this error.
    .PARAMETER TargetObject
        The object that was being operated on when the error occurred.
    .OUTPUTS
        [System.Management.Automation.ErrorRecord] A new error record
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Exception]$Exception,

        [Parameter()]
        [System.Management.Automation.ErrorCategory]$Category = [System.Management.Automation.ErrorCategory]::NotSpecified,

        [Parameter()]
        [string]$ErrorId = "MarkdownLintError",

        [Parameter()]
        [object]$TargetObject = $null
    )

    return [System.Management.Automation.ErrorRecord]::new(
        $Exception,
        $ErrorId,
        $Category,
        $TargetObject
    )
}

# Export functions
Export-ModuleMember -Function Get-FormattedErrorMessage, Write-ErrorWithContext, New-ErrorRecord