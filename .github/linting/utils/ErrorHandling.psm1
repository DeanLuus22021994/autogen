# .github\linting\utils\ErrorHandling.psm1
# Standardized error handling for markdown linting

using namespace System.Management.Automation
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Provides standardized error handling functions for the markdown linting system.
.DESCRIPTION
    A module that offers consistent error handling, formatting, and reporting
    across the markdown linting system.
#>

function Get-FormattedErrorMessage {
    <#
    .SYNOPSIS
        Formats an error record into a readable message.
    .DESCRIPTION
        Creates a standardized error message from an error record.
    .PARAMETER ErrorRecord
        The error record to format.
    .OUTPUTS
        [string] The formatted error message.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ErrorRecord]$ErrorRecord
    )

    $message = "Error in markdown linting: " + $ErrorRecord.Exception.Message
    return $message