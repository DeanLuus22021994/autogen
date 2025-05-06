# LegalDocumentAnalysis.psm1
<#
.SYNOPSIS
    PowerShell module for legal document analysis functions.

.DESCRIPTION
    This module contains the core functionality for the legal document analysis system,
    including text extraction, AI processing, timeline generation, and visualization.
#>

# Module variables
$ModuleRoot = $PSScriptRoot
$ConfigFilePath = Join-Path $ModuleRoot "legal-analysis-config.xml"

# Check if running in a Docker container
$IsContainer = [bool](Get-ChildItem Env:\ | Where-Object { $_.Name -eq "DOTNET_RUNNING_IN_CONTAINER" -or $_.Name -eq "RUNNING_IN_CONTAINER" })

# Default model information
$DefaultModel = @{
    Type = "ai/mistral-nemo"
    QuantizationLevel = "int8"
    Endpoint = "http://localhost:8000/v1/chat/completions"
}

#region Text Extraction Functions

function Get-TextFromPdf {
    <#
    .SYNOPSIS
        Extracts text from a PDF file.

    .PARAMETER FilePath
        Path to the PDF file.

    .PARAMETER FirstPageOnly
        If specified, only extracts text from the first page.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [switch]$FirstPageOnly
    )

    try {
        # Ensure path exists
        if (-not (Test-Path $FilePath)) {
            throw "PDF file not found: $FilePath"
        }

        # Check for pdftotext tool
        $pdfToText = Get-Command "pdftotext.exe" -ErrorAction SilentlyContinue

        if (-not $pdfToText) {
            throw "pdftotext tool not found. Please ensure xpdf-tools is installed."
        }

        # Create temporary file for output
        $tempFile = [System.IO.Path]::GetTempFileName()

        # Extract text
        if ($FirstPageOnly) {
            $process = Start-Process -FilePath $pdfToText.Source -ArgumentList @("-f", "1", "-l", "1", "`"$FilePath`"", "`"$tempFile`"") -NoNewWindow -Wait -PassThru
        } else {
            $process = Start-Process -FilePath $pdfToText.Source -ArgumentList @("`"$FilePath`"", "`"$tempFile`"") -NoNewWindow -Wait -PassThru
        }

        if ($process.ExitCode -ne 0) {
            throw "Failed to extract text from PDF. Exit code: $($process.ExitCode)"
        }

        # Read extracted text
        $extractedText = Get-Content -Path $tempFile -Raw -Encoding UTF8

        # Clean up temporary file
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

        return $extractedText
    } catch {
        Write-Error "Error extracting text from PDF: $_"
        return $null
    }
}

function Get-TextFromDocx {
    <#
    .SYNOPSIS
        Extracts text from a DOCX file.

    .PARAMETER FilePath
        Path to the DOCX file.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    try {
        # Ensure path exists
        if (-not (Test-Path $FilePath)) {
            throw "DOCX file not found: $FilePath"
        }

        # Use Word COM object if available
        try {
            $word = New-Object -ComObject Word.Application
            $word.Visible = $false

            $doc = $word.Documents.Open($FilePath)
            $text = $doc.Content.Text

            $doc.Close()
            $word.Quit()

            # Release COM objects
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null

            return $text
        } catch {
            Write-Warning "Could not use Word COM object: $_"

            # Fallback to unzip and read as XML
            $tempFolder = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

            try {
                Expand-Archive -Path $FilePath -DestinationPath $tempFolder -Force

                $documentXml = Join-Path $tempFolder "word\document.xml"
                if (Test-Path $documentXml) {
                    [xml]$content = Get-Content -Path $documentXml -Raw
                    $text = $content.document.body.InnerText
                    return $text
                } else {
                    throw "Could not find document.xml in the DOCX file"
                }
            } finally {
                # Clean up
                Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Error "Error extracting text from DOCX: $_"
        return $null
    }
}

function Get-DocumentText {
    <#
    .SYNOPSIS
        Extracts text from a document file.

    .PARAMETER FilePath
        Path to the document file (PDF, DOCX, or TXT).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    try {
        # Ensure path exists
        if (-not (Test-Path $FilePath)) {
            throw "File not found: $FilePath"
        }

        # Determine file type and use appropriate extraction method
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()

        switch ($extension) {
            ".pdf" {
                return Get-TextFromPdf -FilePath $FilePath
            }

            ".docx" {
                return Get-TextFromDocx -FilePath $FilePath
            }

            ".txt" {
                return Get-Content -Path $FilePath -Raw -Encoding UTF8
            }

            default {
                throw "Unsupported file format: $extension. Only PDF, DOCX, and TXT files are supported."
            }
        }
    } catch {
        Write-Error "Error extracting text from document: $_"
        return $null
    }
}

#endregion

#region AI Processing Functions

function Get-EventsFromText {
    <#
    .SYNOPSIS
        Extracts events from document text using AI.

    .PARAMETER Text
        The document text to analyze.

    .PARAMETER ModelType
        The AI model type to use for analysis.

    .PARAMETER QuantizationLevel
        The quantization level for the model.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [string]$ModelType = $DefaultModel.Type,

        [Parameter(Mandatory = $false)]
        [string]$QuantizationLevel = $DefaultModel.QuantizationLevel
    )

    try {
        # Prepare prompt for the model
        $prompt = @"
You are analyzing a legal document to extract events and create a timeline.
Extract all events mentioned in the document including dates, actions, people involved, and descriptions.

For each event, provide the following information in JSON format:
1. Date: The date of the event in ISO format (YYYY-MM-DD) if available
2. Action: The main action or event type (e.g., FILED, HEARING, ORDER, etc.)
3. Description: A short description of what happened
4. Parties: People or organizations involved in this specific event
5. Location: Where the event took place (if mentioned)

Output the results as a valid JSON array of events, sorted by date.

Here's the document text:
$Text
"@

        # Call model through Docker Model Runner
        $response = Invoke-AICompletion -Prompt $prompt -ModelType $ModelType -QuantizationLevel $QuantizationLevel

        # Extract JSON from response
        $jsonMatch = [regex]::Match($response, '\[\s*\{.*\}\s*\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)

        if ($jsonMatch.Success) {
            $jsonText = $jsonMatch.Value
            try {
                $events = $jsonText | ConvertFrom-Json
                return $events
            } catch {
                Write-Warning "Could not parse JSON response: $_"
                return @()
            }
        } else {
            Write-Warning "No valid JSON found in model response"
            return @()
        }
    } catch {
        Write-Error "Error extracting events from text: $_"
        return @()
    }
}

function Get-SentimentFromText {
    <#
    .SYNOPSIS
        Analyzes sentiment in document text using AI.

    .PARAMETER Text
        The document text to analyze.

    .PARAMETER ModelType
        The AI model type to use for analysis.

    .PARAMETER QuantizationLevel
        The quantization level for the model.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [string]$ModelType = $DefaultModel.Type,

        [Parameter(Mandatory = $false)]
        [string]$QuantizationLevel = $DefaultModel.QuantizationLevel
    )

    try {
        # Break text into manageable chunks if needed
        $maxChunkSize = 12000  # Adjust based on model context size
        $chunks = @()

        if ($Text.Length -gt $maxChunkSize) {
            # Simple chunking by paragraphs
            $paragraphs = $Text -split '(\r?\n){2,}'
            $currentChunk = ""

            foreach ($paragraph in $paragraphs) {
                if (($currentChunk.Length + $paragraph.Length) -lt $maxChunkSize) {
                    $currentChunk += "`n" + $paragraph
                } else {
                    if ($currentChunk -ne "") {
                        $chunks += $currentChunk
                    }
                    $currentChunk = $paragraph
                }
            }

            if ($currentChunk -ne "") {
                $chunks += $currentChunk
            }
        } else {
            $chunks = @($Text)
        }

        $allSentiments = @()

        foreach ($chunk in $chunks) {
            # Prepare prompt for the model
            $prompt = @"
You are analyzing the language and sentiment in a legal document.
Identify the emotional tone, bias, and sentiment in the text.

For each significant passage or statement, provide:
1. Text: The relevant text being analyzed
2. Sentiment: The emotional tone (positive, negative, or neutral)
3. Intensity: A numerical score from -5 (very negative) to +5 (very positive), with 0 being neutral
4. BiasIndicators: Key words or phrases that indicate bias
5. Context: How this sentiment relates to the legal case

Output the results as a valid JSON array, focusing on the most legally significant statements.

Here's the document text:
$chunk
"@

            # Call model through Docker Model Runner
            $response = Invoke-AICompletion -Prompt $prompt -ModelType $ModelType -QuantizationLevel $QuantizationLevel

            # Extract JSON from response
            $jsonMatch = [regex]::Match($response, '\[\s*\{.*\}\s*\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)

            if ($jsonMatch.Success) {
                $jsonText = $jsonMatch.Value
                try {
                    $sentiments = $jsonText | ConvertFrom-Json
                    $allSentiments += $sentiments
                } catch {
                    Write-Warning "Could not parse JSON response for sentiment analysis: $_"
                }
            } else {
                Write-Warning "No valid JSON found in model response for sentiment analysis"
            }
        }

        return $allSentiments
    } catch {
        Write-Error "Error analyzing sentiment in text: $_"
        return @()
    }
}

function Get-EntitiesFromText {
    <#
    .SYNOPSIS
        Extracts entities from document text using AI.

    .PARAMETER Text
        The document text to analyze.

    .PARAMETER ModelType
        The AI model type to use for analysis.

    .PARAMETER QuantizationLevel
        The quantization level for the model.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [string]$ModelType = $DefaultModel.Type,

        [Parameter(Mandatory = $false)]
        [string]$QuantizationLevel = $DefaultModel.QuantizationLevel
    )

    try {
        # Prepare prompt for the model
        $prompt = @"
You are analyzing a legal document to extract important entities.
Identify all persons, organizations, locations, roles, and case identifiers in the text.

For each entity, provide:
1. Type: The entity type (PERSON, ORGANIZATION, LOCATION, ROLE, IDENTIFIER)
2. Text: The exact text of the entity
3. Aliases: Other names or references to the same entity
4. Context: Brief description of the entity's role in the document
5. Frequency: How many times the entity appears (approximately)

Output the results as a valid JSON array, sorted by entity type and frequency.

Here's the document text:
$Text
"@

        # Call model through Docker Model Runner
        $response = Invoke-AICompletion -Prompt $prompt -ModelType $ModelType -QuantizationLevel $QuantizationLevel

        # Extract JSON from response
        $jsonMatch = [regex]::Match($response, '\[\s*\{.*\}\s*\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)

        if ($jsonMatch.Success) {
            $jsonText = $jsonMatch.Value
            try {
                $entities = $jsonText | ConvertFrom-Json
                return $entities
            } catch {
                Write-Warning "Could not parse JSON response for entity extraction: $_"
                return @()
            }
        } else {
            Write-Warning "No valid JSON found in model response for entity extraction"
            return @()
        }
    } catch {
        Write-Error "Error extracting entities from text: $_"
        return @()
    }
}

function Invoke-AICompletion {
    <#
    .SYNOPSIS
        Sends a prompt to the AI model and gets a completion.

    .PARAMETER Prompt
        The prompt to send to the model.

    .PARAMETER ModelType
        The AI model type to use.

    .PARAMETER QuantizationLevel
        The quantization level for the model.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [string]$ModelType = $DefaultModel.Type,

        [Parameter(Mandatory = $false)]
        [string]$QuantizationLevel = $DefaultModel.QuantizationLevel
    )

    try {
        # Get endpoint from environment or use default
        $endpoint = $env:MODEL_RUNNER_ENDPOINT ?? $DefaultModel.Endpoint

        # Prepare request body
        $requestBody = @{
            model = $ModelType
            messages = @(
                @{
                    role = "system"
                    content = "You are a legal document analysis assistant that specializes in extracting structured information from legal documents."
                },
                @{
                    role = "user"
                    content = $Prompt
                }
            )
            max_tokens = 4000
        }

        # Add quantization level if specified
        if ($QuantizationLevel -ne "none") {
            $requestBody.Add("quantization", $QuantizationLevel)
        }

        # Convert to JSON
        $requestJson = $requestBody | ConvertTo-Json -Depth 10

        # Send request to Docker Model Runner
        $headers = @{
            "Content-Type" = "application/json"
        }

        $response = Invoke-RestMethod -Uri $endpoint -Method Post -Body $requestJson -Headers $headers

        # Extract and return the model's response
        if ($response.choices -and $response.choices.Count -gt 0) {
            return $response.choices[0].message.content
        } else {
            throw "No response from model"
        }
    } catch {
        Write-Error "Error invoking AI completion: $_"
        throw
    }
}

#endregion

#region Visualization Functions

function New-TimelineVisualization {
    <#
    .SYNOPSIS
        Creates a timeline visualization from events.

    .PARAMETER Events
        The events to visualize.

    .PARAMETER OutputPath
        Path where the timeline visualization will be saved.

    .PARAMETER Entities
        Entity information to enhance the visualization.

    .PARAMETER Sentiments
        Sentiment information to enhance the visualization.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Events,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [object[]]$Entities,

        [Parameter(Mandatory = $false)]
        [object[]]$Sentiments
    )

    try {
        # Ensure ImportExcel module is available
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Error "ImportExcel module not found. Please install it with: Install-Module -Name ImportExcel -Force"
            return $false
        }

        # Create Excel package
        $excel = New-Object -TypeName OfficeOpenXml.ExcelPackage

        # Add timeline worksheet
        $timelineSheet = $excel.Workbook.Worksheets.Add("Timeline")

        # Add headers
        $timelineSheet.Cells["A1"].Value = "Date"
        $timelineSheet.Cells["B1"].Value = "Action"
        $timelineSheet.Cells["C1"].Value = "Description"
        $timelineSheet.Cells["D1"].Value = "Parties"
        $timelineSheet.Cells["E1"].Value = "Location"

        # Style headers
        $headerRange = $timelineSheet.Cells["A1:E1"]
        $headerRange.Style.Font.Bold = $true
        $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
        $headerRange.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightGray)

        # Add events data
        $row = 2
        foreach ($event in $Events) {
            # Convert date string to Excel date
            if ($event.Date) {
                $date = if ($event.Date -is [DateTime]) {
                    $event.Date
                } elseif ($event.Date -match '^\d{4}-\d{2}-\d{2}') {
                    try {
                        [DateTime]::ParseExact($event.Date, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
                    } catch {
                        $null
                    }
                } else {
                    $null
                }

                if ($date) {
                    $timelineSheet.Cells["A$row"].Value = $date
                    $timelineSheet.Cells["A$row"].Style.Numberformat.Format = "yyyy-mm-dd"
                } else {
                    $timelineSheet.Cells["A$row"].Value = $event.Date
                }
            }

            $timelineSheet.Cells["B$row"].Value = $event.Action
            $timelineSheet.Cells["C$row"].Value = $event.Description
            $timelineSheet.Cells["D$row"].Value = $event.Parties -join ", "
            $timelineSheet.Cells["E$row"].Value = $event.Location

            # Conditional formatting based on action
            switch -Regex ($event.Action) {
                "FILED|PETITION" {
                    $timelineSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::DarkBlue)
                }
                "HEARING|TRIAL" {
                    $timelineSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::DarkGreen)
                }
                "ORDER|RULING" {
                    $timelineSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::DarkRed)
                    $timelineSheet.Cells["B$row"].Style.Font.Bold = $true
                }
                "MOTION" {
                    $timelineSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Purple)
                }
            }

            $row++
        }

        # Auto size columns
        $timelineSheet.Cells[$timelineSheet.Dimension.Address].AutoFitColumns()

        # Add sentiment worksheet if we have data
        if ($Sentiments -and $Sentiments.Count -gt 0) {
            $sentimentSheet = $excel.Workbook.Worksheets.Add("Sentiment")

            # Add headers
            $sentimentSheet.Cells["A1"].Value = "Text"
            $sentimentSheet.Cells["B1"].Value = "Sentiment"
            $sentimentSheet.Cells["C1"].Value = "Intensity"
            $sentimentSheet.Cells["D1"].Value = "Bias Indicators"
            $sentimentSheet.Cells["E1"].Value = "Context"

            # Style headers
            $headerRange = $sentimentSheet.Cells["A1:E1"]
            $headerRange.Style.Font.Bold = $true
            $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $headerRange.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightGray)

            # Add sentiment data
            $row = 2
            foreach ($sentiment in $Sentiments) {
                $sentimentSheet.Cells["A$row"].Value = $sentiment.Text
                $sentimentSheet.Cells["B$row"].Value = $sentiment.Sentiment
                $sentimentSheet.Cells["C$row"].Value = $sentiment.Intensity
                $sentimentSheet.Cells["D$row"].Value = ($sentiment.BiasIndicators -join ", ")
                $sentimentSheet.Cells["E$row"].Value = $sentiment.Context

                # Conditional formatting based on sentiment
                switch ($sentiment.Sentiment) {
                    "positive" {
                        $sentimentSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Green)
                    }
                    "negative" {
                        $sentimentSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Red)
                    }
                    "neutral" {
                        $sentimentSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)
                    }
                }

                # Conditional formatting based on intensity
                if ($sentiment.Intensity -gt 3) {
                    $sentimentSheet.Cells["C$row"].Style.Font.Bold = $true
                }

                if ($sentiment.Intensity -gt 0) {
                    $sentimentSheet.Cells["C$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Green)
                } elseif ($sentiment.Intensity -lt 0) {
                    $sentimentSheet.Cells["C$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Red)
                } else {
                    $sentimentSheet.Cells["C$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)
                }

                $row++
            }

            # Auto size columns
            $sentimentSheet.Cells[$sentimentSheet.Dimension.Address].AutoFitColumns()
        }

        # Add entities worksheet if we have data
        if ($Entities -and $Entities.Count -gt 0) {
            $entitySheet = $excel.Workbook.Worksheets.Add("Entities")

            # Add headers
            $entitySheet.Cells["A1"].Value = "Entity Type"
            $entitySheet.Cells["B1"].Value = "Entity Text"
            $entitySheet.Cells["C1"].Value = "Frequency"
            $entitySheet.Cells["D1"].Value = "Context"
            $entitySheet.Cells["E1"].Value = "Aliases"

            # Style headers
            $headerRange = $entitySheet.Cells["A1:E1"]
            $headerRange.Style.Font.Bold = $true
            $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $headerRange.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightGray)

            # Add data
            $row = 2
            foreach ($entity in ($Entities | Sort-Object -Property Frequency -Descending)) {
                $entitySheet.Cells["A$row"].Value = $entity.Type
                $entitySheet.Cells["B$row"].Value = $entity.Text
                $entitySheet.Cells["C$row"].Value = $entity.Frequency
                $entitySheet.Cells["D$row"].Value = $entity.Context
                $entitySheet.Cells["E$row"].Value = ($entity.Aliases -join ", ")

                # Conditional formatting based on entity type
                switch ($entity.Type) {
                    "PERSON" {
                        $entitySheet.Cells["A$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Blue)
                    }
                    "ORGANIZATION" {
                        $entitySheet.Cells["A$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Green)
                    }
                    "LOCATION" {
                        $entitySheet.Cells["A$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Purple)
                    }
                    "ROLE" {
                        $entitySheet.Cells["A$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Orange)
                    }
                    "IDENTIFIER" {
                        $entitySheet.Cells["A$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Red)
                    }
                }

                $row++
            }

            # Auto size columns
            $entitySheet.Cells[$entitySheet.Dimension.Address].AutoFitColumns()
        }

        # Save the Excel file
        $excel.SaveAs((New-Object System.IO.FileInfo($OutputPath)))
        $excel.Dispose()

        Write-Host "Timeline visualization created: $OutputPath" -ForegroundColor Green
        return $true
    } catch {
        Write-Error "Error creating timeline visualization: $_"
        return $false
    }
}

function New-TextReport {
    <#
    .SYNOPSIS
        Creates a text report summarizing the document analysis.

    .PARAMETER DocumentText
        The original document text.

    .PARAMETER Events
        Extracted events from the document.

    .PARAMETER Entities
        Extracted entities from the document.

    .PARAMETER Sentiments
        Sentiment analysis results.

    .PARAMETER OutputPath
        Path where the text report will be saved.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DocumentText,

        [Parameter(Mandatory = $true)]
        [object[]]$Events,

        [Parameter(Mandatory = $false)]
        [object[]]$Entities,

        [Parameter(Mandatory = $false)]
        [object[]]$Sentiments,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    try {
        $report = @"
===============================================================================
                       LEGAL DOCUMENT ANALYSIS REPORT
===============================================================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

-------------------------------------------------------------------------------
                             DOCUMENT SUMMARY
-------------------------------------------------------------------------------
Document Length: $($DocumentText.Length) characters
Events Detected: $($Events.Count)
Entities Detected: $($Entities.Count)
Sentiment Passages Analyzed: $($Sentiments.Count)

-------------------------------------------------------------------------------
                               TIMELINE
-------------------------------------------------------------------------------

"@

        # Add events to report
        if ($Events -and $Events.Count -gt 0) {
            $sortedEvents = $Events | Sort-Object -Property @{Expression = {
                if ($_.Date -is [DateTime]) {
                    $_.Date
                } elseif ($_.Date -match '^\d{4}-\d{2}-\d{2}') {
                    try {
                        [DateTime]::ParseExact($_.Date, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
                    } catch {
                        [DateTime]::MinValue
                    }
                } else {
                    [DateTime]::MinValue
                }
            }}

            foreach ($event in $sortedEvents) {
                $report += @"
Date: $($event.Date)
Action: $($event.Action)
Description: $($event.Description)
$(if($event.Parties){"Parties: $($event.Parties -join ", ")"})
$(if($event.Location){"Location: $($event.Location)"})
-------------------------------------------------------------------------------

"@
            }
        } else {
            $report += "No events detected in the document.`r`n`r`n"
        }

        # Add sentiment analysis
        $report += @"
-------------------------------------------------------------------------------
                            SENTIMENT ANALYSIS
-------------------------------------------------------------------------------

"@

        if ($Sentiments -and $Sentiments.Count -gt 0) {
            $positiveSentiments = $Sentiments | Where-Object { $_.Sentiment -eq "positive" }
            $negativeSentiments = $Sentiments | Where-Object { $_.Sentiment -eq "negative" }
            $neutralSentiments = $Sentiments | Where-Object { $_.Sentiment -eq "neutral" }

            $report += @"
Sentiment Distribution:
  Positive: $($positiveSentiments.Count) passages
  Negative: $($negativeSentiments.Count) passages
  Neutral: $($neutralSentiments.Count) passages

Most Significant Sentiment Passages:
"@

            # Add most significant positive sentiments
            if ($positiveSentiments -and $positiveSentiments.Count -gt 0) {
                $topPositive = $positiveSentiments | Sort-Object -Property Intensity -Descending | Select-Object -First 3

                $report += "`r`nPositive Passages:`r`n"
                foreach ($sentiment in $topPositive) {
                    $report += @"
"$($sentiment.Text)"
   - Intensity: $($sentiment.Intensity)/5
   - Context: $($sentiment.Context)

"@
                }
            }

            # Add most significant negative sentiments
            if ($negativeSentiments -and $negativeSentiments.Count -gt 0) {
                $topNegative = $negativeSentiments | Sort-Object -Property Intensity | Select-Object -First 3

                $report += "`r`nNegative Passages:`r`n"
                foreach ($sentiment in $topNegative) {
                    $report += @"
"$($sentiment.Text)"
   - Intensity: $($sentiment.Intensity)/5
   - Context: $($sentiment.Context)

"@
                }
            }
        } else {
            $report += "No sentiment analysis results available.`r`n`r`n"
        }

        # Add entity analysis
        $report += @"
-------------------------------------------------------------------------------
                             ENTITY ANALYSIS
-------------------------------------------------------------------------------

"@

        if ($Entities -and $Entities.Count -gt 0) {
            $personEntities = $Entities | Where-Object { $_.Type -eq "PERSON" } | Sort-Object -Property Frequency -Descending
            $orgEntities = $Entities | Where-Object { $_.Type -eq "ORGANIZATION" } | Sort-Object -Property Frequency -Descending
            $locEntities = $Entities | Where-Object { $_.Type -eq "LOCATION" } | Sort-Object -Property Frequency -Descending
            $roleEntities = $Entities | Where-Object { $_.Type -eq "ROLE" } | Sort-Object -Property Frequency -Descending
            $idEntities = $Entities | Where-Object { $_.Type -eq "IDENTIFIER" } | Sort-Object -Property Frequency -Descending

            # Add person entities
            if ($personEntities -and $personEntities.Count -gt 0) {
                $report += "PERSONS:`r`n"
                foreach ($entity in $personEntities) {
                    $report += @"
- $($entity.Text) (Frequency: $($entity.Frequency))
  Context: $($entity.Context)
  $(if($entity.Aliases){"Aliases: $($entity.Aliases -join ", ")"})

"@
                }
            }

            # Add organization entities
            if ($orgEntities -and $orgEntities.Count -gt 0) {
                $report += "ORGANIZATIONS:`r`n"
                foreach ($entity in $orgEntities) {
                    $report += @"
- $($entity.Text) (Frequency: $($entity.Frequency))
  Context: $($entity.Context)
  $(if($entity.Aliases){"Aliases: $($entity.Aliases -join ", ")"})

"@
                }
            }

            # Add location entities
            if ($locEntities -and $locEntities.Count -gt 0) {
                $report += "LOCATIONS:`r`n"
                foreach ($entity in $locEntities) {
                    $report += @"
- $($entity.Text) (Frequency: $($entity.Frequency))
  Context: $($entity.Context)

"@
                }
            }

            # Add role entities
            if ($roleEntities -and $roleEntities.Count -gt 0) {
                $report += "ROLES:`r`n"
                foreach ($entity in $roleEntities) {
                    $report += @"
- $($entity.Text) (Frequency: $($entity.Frequency))
  Context: $($entity.Context)

"@
                }
            }

            # Add identifier entities
            if ($idEntities -and $idEntities.Count -gt 0) {
                $report += "IDENTIFIERS:`r`n"
                foreach ($entity in $idEntities) {
                    $report += @"
- $($entity.Text) (Frequency: $($entity.Frequency))
  Context: $($entity.Context)

"@
                }
            }
        } else {
            $report += "No entities detected in the document.`r`n`r`n"
        }

        # Add footer
        $report += @"
===============================================================================
                    END OF LEGAL DOCUMENT ANALYSIS REPORT
===============================================================================
"@

        # Write report to file
        $report | Out-File -FilePath $OutputPath -Encoding utf8

        Write-Host "Text report created: $OutputPath" -ForegroundColor Green
        return $true
    } catch {
        Write-Error "Error creating text report: $_"
        return $false
    }
}

#endregion

# Export module functions
Export-ModuleMember -Function @(
    'Get-TextFromPdf',
    'Get-TextFromDocx',
    'Get-DocumentText',
    'Get-EventsFromText',
    'Get-SentimentFromText',
    'Get-EntitiesFromText',
    'Invoke-AICompletion',
    'New-TimelineVisualization',
    'New-TextReport'
)
