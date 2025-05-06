# PowerShell script to test smoll2 LLM performance with RAM disk and GPU

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$Detailed,

    [Parameter(Mandatory = $false)]
    [switch]$CompareWithMemoryOnly,

    [Parameter(Mandatory = $false)]
    [int]$NumRequests = 10,

    [Parameter(Mandatory = $false)]
    [int]$TokenLength = 100
)

$ErrorActionPreference = 'Stop'
$GREEN = [ConsoleColor]::Green
$YELLOW = [ConsoleColor]::Yellow
$RED = [ConsoleColor]::Red
$CYAN = [ConsoleColor]::Cyan
$WHITE = [ConsoleColor]::White

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

function Test-ModelEndpoint {
    param (
        [string]$Endpoint = "http://localhost:8080/v1/chat/completions"
    )

    try {
        $response = Invoke-WebRequest -Uri $Endpoint -Method "OPTIONS" -TimeoutSec 5
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Measure-ModelPerformance {
    param (
        [string]$ModelEndpoint = "http://localhost:8080/v1/chat/completions",
        [string]$ModelName = "smoll2",
        [int]$NumRequests = 5,
        [int]$TokenLength = 100
    )

    $results = @()
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer default-dev-key"
    }

    Write-Host "$(Get-TimeStamp) Starting performance test with $NumRequests requests..." -ForegroundColor $CYAN

    for ($i = 1; $i -le $NumRequests; $i++) {
        Write-Host "$(Get-TimeStamp) Running request $i of $NumRequests..." -ForegroundColor $CYAN

        $body = @{
            model = $ModelName
            messages = @(
                @{
                    role = "system"
                    content = "You are a helpful assistant that writes concise responses."
                },
                @{
                    role = "user"
                    content = "Write a short paragraph about artificial intelligence. Keep it approximately $TokenLength tokens."
                }
            )
            max_tokens = $TokenLength
            temperature = 0.7
        } | ConvertTo-Json

        $start = Get-Date
        $success = $true
        $errorMessage = ""

        try {
            $response = Invoke-WebRequest -Uri $ModelEndpoint -Method "POST" -Headers $headers -Body $body -TimeoutSec 60
            $responseContent = $response.Content | ConvertFrom-Json
            $tokensGenerated = $responseContent.usage.completion_tokens
        } catch {
            $success = $false
            $errorMessage = $_.Exception.Message
            $tokensGenerated = 0
        }

        $end = Get-Date
        $duration = ($end - $start).TotalSeconds

        $results += [PSCustomObject]@{
            RequestId = $i
            Success = $success
            Duration = $duration
            TokensGenerated = $tokensGenerated
            TokensPerSecond = if ($tokensGenerated -gt 0 -and $duration -gt 0) { $tokensGenerated / $duration } else { 0 }
            Error = $errorMessage
        }

        if ($success) {
            Write-Host "$(Get-TimeStamp) Request $i completed in $($duration.ToString("F2")) seconds, $tokensGenerated tokens ($(($tokensGenerated / $duration).ToString("F2")) tokens/sec)" -ForegroundColor $GREEN
        } else {
            Write-Host "$(Get-TimeStamp) Request $i failed: $errorMessage" -ForegroundColor $RED
        }

        # Small delay between requests
        Start-Sleep -Seconds 1
    }

    return $results
}

function Show-PerformanceSummary {
    param (
        [PSObject[]]$Results
    )

    $successfulRequests = $Results | Where-Object { $_.Success }
    $failedRequests = $Results | Where-Object { -not $_.Success }

    $totalRequests = $Results.Count
    $successCount = $successfulRequests.Count
    $failRate = if ($totalRequests -gt 0) { ($failedRequests.Count / $totalRequests) * 100 } else { 0 }

    if ($successCount -gt 0) {
        $avgDuration = ($successfulRequests | Measure-Object -Property Duration -Average).Average
        $avgTokensPerSecond = ($successfulRequests | Measure-Object -Property TokensPerSecond -Average).Average
        $minTokensPerSecond = ($successfulRequests | Measure-Object -Property TokensPerSecond -Minimum).Minimum
        $maxTokensPerSecond = ($successfulRequests | Measure-Object -Property TokensPerSecond -Maximum).Maximum

        Write-Host "`n📊 Performance Summary" -ForegroundColor $CYAN
        Write-Host "Total Requests: $totalRequests" -ForegroundColor $WHITE
        Write-Host "Successful: $successCount ($(100 - $failRate)%)" -ForegroundColor $GREEN
        Write-Host "Failed: $($failedRequests.Count) ($($failRate)%)" -ForegroundColor $(if ($failRate -gt 0) { $RED } else { $GREEN })
        Write-Host "Average Duration: $($avgDuration.ToString("F2")) seconds" -ForegroundColor $WHITE
        Write-Host "Average Tokens/Second: $($avgTokensPerSecond.ToString("F2"))" -ForegroundColor $WHITE
        Write-Host "Min Tokens/Second: $($minTokensPerSecond.ToString("F2"))" -ForegroundColor $WHITE
        Write-Host "Max Tokens/Second: $($maxTokensPerSecond.ToString("F2"))" -ForegroundColor $WHITE
    } else {
        Write-Host "`n❌ No successful requests to analyze" -ForegroundColor $RED
    }
}

# Check if the model endpoint is available
Write-Host "$(Get-TimeStamp) Checking model endpoint..." -ForegroundColor $CYAN
if (-not (Test-ModelEndpoint)) {
    Write-Host "❌ Model endpoint not available. Make sure the smoll2 service is running." -ForegroundColor $RED
    Write-Host "Run Start-Smoll2RamDiskGPU.ps1 to set up and start the service." -ForegroundColor $WHITE
    exit 1
}

Write-Host "$(Get-TimeStamp) Model endpoint available. Starting performance test..." -ForegroundColor $GREEN

# Check GPU status
$gpuAvailable = $false
try {
    $gpuStatus = docker exec autogen-smoll2-gpu nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader 2>$null
    if ($LASTEXITCODE -eq 0) {
        $gpuAvailable = $true
        Write-Host "$(Get-TimeStamp) GPU utilization: $gpuStatus%" -ForegroundColor $GREEN
    }
} catch {
    Write-Host "$(Get-TimeStamp) GPU status check failed: $_" -ForegroundColor $YELLOW
}

# Check RAM disk status
$ramDiskEnabled = $false
try {
    $ramDiskStatus = docker exec autogen-smoll2-gpu bash -c "mount | grep '/mnt/ramdisk'" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $ramDiskEnabled = $true
        Write-Host "$(Get-TimeStamp) RAM disk is mounted: $ramDiskStatus" -ForegroundColor $GREEN
    }
} catch {
    Write-Host "$(Get-TimeStamp) RAM disk status check failed: $_" -ForegroundColor $YELLOW
}

Write-Host "$(Get-TimeStamp) Running performance test with smoll2..." -ForegroundColor $CYAN
$results = Measure-ModelPerformance -NumRequests $NumRequests -TokenLength $TokenLength

# Display performance summary
Show-PerformanceSummary -Results $results

# If detailed output is requested
if ($Detailed) {
    Write-Host "`n📝 Detailed Results" -ForegroundColor $CYAN
    $results | Format-Table -Property RequestId, Success, Duration, TokensGenerated, TokensPerSecond -AutoSize
}

# Compare with memory-only if requested
if ($CompareWithMemoryOnly -and $ramDiskEnabled) {
    Write-Host "`n🔄 Running comparison test with memory-only configuration..." -ForegroundColor $CYAN
    Write-Host "This will temporarily disable the RAM disk for comparison purposes." -ForegroundColor $YELLOW

    $confirm = Read-Host "Do you want to continue? (Y/N)"
    if ($confirm -eq "Y" -or $confirm -eq "y") {
        try {
            # Temporarily disable RAM disk
            docker exec autogen-smoll2-gpu bash -c "export RAM_DISK_ENABLED=false && export MODEL_PATH=/tmp/models/smoll2"

            # Run memory-only test
            Write-Host "$(Get-TimeStamp) Running memory-only performance test..." -ForegroundColor $CYAN
            $memoryResults = Measure-ModelPerformance -NumRequests $NumRequests -TokenLength $TokenLength

            # Show results
            Write-Host "`n📊 Memory-Only Performance Summary" -ForegroundColor $CYAN
            Show-PerformanceSummary -Results $memoryResults

            # Calculate performance difference
            $ramDiskAvg = ($results | Where-Object { $_.Success } | Measure-Object -Property TokensPerSecond -Average).Average
            $memoryAvg = ($memoryResults | Where-Object { $_.Success } | Measure-Object -Property TokensPerSecond -Average).Average

            if ($ramDiskAvg -gt 0 -and $memoryAvg -gt 0) {
                $improvementPercent = (($ramDiskAvg - $memoryAvg) / $memoryAvg) * 100

                Write-Host "`n📈 Performance Comparison" -ForegroundColor $CYAN
                Write-Host "RAM Disk Performance: $($ramDiskAvg.ToString("F2")) tokens/sec" -ForegroundColor $WHITE
                Write-Host "Memory-Only Performance: $($memoryAvg.ToString("F2")) tokens/sec" -ForegroundColor $WHITE

                if ($improvementPercent -gt 0) {
                    Write-Host "Performance Improvement: +$($improvementPercent.ToString("F2"))%" -ForegroundColor $GREEN
                } else {
                    Write-Host "Performance Change: $($improvementPercent.ToString("F2"))%" -ForegroundColor $(if ($improvementPercent -lt -10) { $RED } else { $YELLOW })
                }
            }

            # Re-enable RAM disk
            docker exec autogen-smoll2-gpu bash -c "export RAM_DISK_ENABLED=true && export MODEL_PATH=/opt/autogen/models/smoll2"
        } catch {
            Write-Host "❌ Error during comparison test: $_" -ForegroundColor $RED
        }
    }
}

Write-Host "`n✅ Performance test completed" -ForegroundColor $GREEN
