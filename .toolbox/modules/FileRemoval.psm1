function Remove-FileWithConfirmation {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$FilePath,
        [switch]$Force,
        [switch]$WhatIf
    )
    process {
        if (-not (Test-Path $FilePath)) {
            Write-Host "Not found: $FilePath" -ForegroundColor Gray
            return
        }
        if ($PSCmdlet.ShouldProcess($FilePath, 'Remove')) {
            try {
                Remove-Item $FilePath -Force:$Force.IsPresent -WhatIf:$WhatIf.IsPresent
                Write-Host "Removed: $FilePath" -ForegroundColor Green
            } catch {
                Write-Host ("Error removing {0}: {1}" -f $FilePath, $_) -ForegroundColor Red
            }
        } else {
            Write-Host "Skipped: $FilePath" -ForegroundColor Yellow
        }
    }
}

Export-ModuleMember -Function Remove-FileWithConfirmation
