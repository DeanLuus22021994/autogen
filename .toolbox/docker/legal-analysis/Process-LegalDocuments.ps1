# Process-LegalDocuments.ps1
<#
.SYNOPSIS
    Processes legal documents to extract timelines, events, and perform sentiment analysis.

.DESCRIPTION
    This script provides automated processing of legal documents (PDF, DOCX, TXT) for docket analysis.
    It extracts text, identifies key events, generates timelines, and performs sentiment analysis
    using local AI models via Docker Model Runner. All processing is done locally without external API calls
    to maintain complete confidentiality and privacy of sensitive legal information.

.PARAMETER WatchFolder
    Path to folder to monitor for new files. When a new file is detected, it will be automatically processed.

.PARAMETER InputFile
    Path to a specific file to process (PDF, DOCX, or TXT).

.PARAMETER OutputFolder
    Path where analysis results will be stored. Default is "./analysis-results".

.PARAMETER ModelType
    The AI model to use for analysis. Default is "ai/mistral-nemo" for optimal performance.

.PARAMETER QuantizationLevel
    Quantization level for the model. Options: "int8" (balanced), "int4" (faster), "none" (highest quality). Default is "int8".

.PARAMETER NoVisualization
    If specified, skips generating visualizations and only outputs raw data and text reports.

.EXAMPLE
    .\Process-LegalDocuments.ps1 -InputFile "C:\Documents\docket_info.pdf" -OutputFolder "C:\Analysis"

.EXAMPLE
    .\Process-LegalDocuments.ps1 -WatchFolder "C:\Incoming_Documents" -ModelType "ai/mistral"
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, ParameterSetName = "Watch")]
    [string]$WatchFolder,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleFile")]
    [string]$InputFile,

    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = "./analysis-results",

    [Parameter(Mandatory = $false)]
    [ValidateSet("ai/mistral-nemo", "ai/mistral", "ai/llama3")]
    [string]$ModelType = "ai/mistral-nemo",

    [Parameter(Mandatory = $false)]
    [ValidateSet("int8", "int4", "none")]
    [string]$QuantizationLevel = "int8",

    [Parameter(Mandatory = $false)]
    [switch]$NoVisualization
)

# Color definitions for console output
$GREEN = [ConsoleColor]::Green
$YELLOW = [ConsoleColor]::Yellow
$RED = [ConsoleColor]::Red
$CYAN = [ConsoleColor]::Cyan
$WHITE = [ConsoleColor]::White
$MAGENTA = [ConsoleColor]::Magenta

# Load required modules
function Load-RequiredModules {
    Write-Host "Loading required modules..." -ForegroundColor $CYAN

    # Check for required modules
    $requiredModules = @(
        @{Name = "PSDockConverter"; MinVersion = "1.0.0"},
        @{Name = "ImportExcel"; MinVersion = "7.0.0"}
    )

    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module.Name | Where-Object { [Version]$_.Version -ge [Version]$module.MinVersion })) {
            Write-Host "Installing $($module.Name) module..." -ForegroundColor $YELLOW
            Install-Module -Name $module.Name -Force -Scope CurrentUser
        }

        Import-Module -Name $module.Name -MinimumVersion $module.MinVersion
    }

    # Check for PDF extraction tool
    if (-not (Get-Command "pdftotext.exe" -ErrorAction SilentlyContinue)) {
        Write-Host "PDF extraction tool not found. Installing..." -ForegroundColor $YELLOW

        # Download xpdf tools if not present
        $xpdfFolder = Join-Path $PSScriptRoot "xpdf-tools"
        if (-not (Test-Path $xpdfFolder)) {
            New-Item -ItemType Directory -Path $xpdfFolder -Force | Out-Null
            $xpdfUrl = "https://dl.xpdfreader.com/xpdf-tools-win-4.04.zip"
            $xpdfZip = Join-Path $env:TEMP "xpdf-tools.zip"

            Invoke-WebRequest -Uri $xpdfUrl -OutFile $xpdfZip
            Expand-Archive -Path $xpdfZip -DestinationPath $xpdfFolder -Force

            # Add to path temporarily
            $env:Path += ";$(Join-Path $xpdfFolder "xpdf-tools-win-4.04\bin64")"
        }
    }

    Write-Host "All required modules loaded successfully" -ForegroundColor $GREEN
}

# Check Docker Model Runner is available
function Test-DockerModelRunner {
    <#
    .SYNOPSIS
        Verifies that Docker Model Runner is available.

    .DESCRIPTION
        Tests if Docker is running and the model-runner endpoint is available.
        Returns $true if the service is available, otherwise $false.

    .EXAMPLE
        if (Test-DockerModelRunner) {
            # Model runner is available, proceed with deployment
        }
    #>
    Write-Host "Verifying Docker Model Runner..." -ForegroundColor $CYAN

    try {
        # Check Docker is running
        docker info | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Docker is not running. Please start Docker Desktop." -ForegroundColor $RED
            return $false
        }

        # Check if model runner is available
        $modelRunnerEndpoint = "http://model-runner.docker.internal/engines"
        try {
            $response = Invoke-WebRequest -Uri $modelRunnerEndpoint -UseBasicParsing -ErrorAction Stop

            if ($response.StatusCode -eq 200) {
                $availableModels = $response.Content | ConvertFrom-Json

                if ($availableModels -contains $ModelType) {
                    Write-Host "Model Runner is available with the selected model: $ModelType" -ForegroundColor $GREEN
                    return $true
                } else {
                    Write-Host "Selected model '$ModelType' is not available. Available models: $($availableModels -join ', ')" -ForegroundColor $RED

                    # Attempt to pull the requested model
                    Write-Host "Pulling requested model: $ModelType..." -ForegroundColor $YELLOW
                    docker model pull $ModelType

                    # Verify again after pull
                    $response = Invoke-WebRequest -Uri $modelRunnerEndpoint -UseBasicParsing -ErrorAction Stop
                    $availableModels = $response.Content | ConvertFrom-Json

                    if ($availableModels -contains $ModelType) {
                        Write-Host "Successfully pulled and loaded model: $ModelType" -ForegroundColor $GREEN
                        return $true
                    } else {
                        Write-Host "Failed to pull model: $ModelType" -ForegroundColor $RED
                        return $false
                    }
                }
            } else {
                Write-Host "Model Runner is not responding correctly. Status code: $($response.StatusCode)" -ForegroundColor $RED
                return $false
            }
        } catch {
            Write-Host "Model Runner is not available. Make sure Docker Model Runner is enabled in Docker Desktop settings." -ForegroundColor $RED
            Write-Host "Error details: $_" -ForegroundColor $RED

            # Try to initialize Docker Model Runner
            $setupScript = Join-Path $PSScriptRoot "..\..\..\Setup-DockerModelRunner.ps1"
            if (Test-Path $setupScript) {
                Write-Host "Attempting to initialize Docker Model Runner..." -ForegroundColor $YELLOW
                & $setupScript -Models $ModelType

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Docker Model Runner initialized successfully" -ForegroundColor $GREEN
                    return $true
                } else {
                    Write-Host "Failed to initialize Docker Model Runner" -ForegroundColor $RED
                    return $false
                }
            }

            return $false
        }
    } catch {
        Write-Host "Error checking Docker Model Runner: $_" -ForegroundColor $RED
        return $false
    }
}

# Extract text from document based on its type
function Extract-DocumentText {
    param (
        [string]$FilePath
    )

    Write-Host "Extracting text from document: $FilePath" -ForegroundColor $CYAN

    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $outputText = $null

    switch ($extension) {
        ".pdf" {
            Write-Host "Processing PDF document..." -ForegroundColor $CYAN
            $tempTextFile = [System.IO.Path]::GetTempFileName()

            try {
                & pdftotext.exe -layout -nopgbrk $FilePath $tempTextFile
                $outputText = Get-Content -Path $tempTextFile -Raw -Encoding UTF8
            } catch {
                Write-Host "Error extracting text from PDF: $_" -ForegroundColor $RED
                $outputText = $null
            } finally {
                if (Test-Path $tempTextFile) {
                    Remove-Item -Path $tempTextFile -Force
                }
            }
        }
        ".docx" {
            Write-Host "Processing Word document..." -ForegroundColor $CYAN
            try {
                $word = New-Object -ComObject Word.Application
                $word.Visible = $false
                $doc = $word.Documents.Open($FilePath)
                $outputText = $doc.Content.Text
                $doc.Close()
                $word.Quit()
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
            } catch {
                Write-Host "Error extracting text from Word document: $_" -ForegroundColor $RED
                $outputText = $null
            }
        }
        ".txt" {
            Write-Host "Processing text document..." -ForegroundColor $CYAN
            try {
                $outputText = Get-Content -Path $FilePath -Raw -Encoding UTF8
            } catch {
                Write-Host "Error reading text file: $_" -ForegroundColor $RED
                $outputText = $null
            }
        }
        default {
            Write-Host "Unsupported file format: $extension" -ForegroundColor $RED
            return $null
        }
    }

    if ($outputText) {
        Write-Host "Successfully extracted $(($outputText -split '\n').Length) lines of text" -ForegroundColor $GREEN
        return $outputText
    } else {
        Write-Host "Failed to extract text from document" -ForegroundColor $RED
        return $null
    }
}

# Analyze document using local AI model
function Analyze-Document {
    param (
        [string]$Text,
        [string]$FileName,
        [string]$OutputPath
    )

    Write-Host "Analyzing document with $ModelType..." -ForegroundColor $CYAN

    if ([string]::IsNullOrWhiteSpace($Text)) {
        Write-Host "No text to analyze!" -ForegroundColor $RED
        return $null
    }

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Output raw text for reference
    $rawTextPath = Join-Path $OutputPath "$([System.IO.Path]::GetFileNameWithoutExtension($FileName))_raw_text.txt"
    Set-Content -Path $rawTextPath -Value $Text -Encoding UTF8

    # Split text into smaller chunks if needed (context window management)
    $maxChunkSize = 12000  # Characters per chunk (adjust based on model capabilities)
    $chunks = @()
    $textLength = $Text.Length

    if ($textLength -le $maxChunkSize) {
        $chunks = @($Text)
    } else {
        $paragraphs = $Text -split '(\r?\n){2,}'
        $currentChunk = ""

        foreach ($paragraph in $paragraphs) {
            if (($currentChunk.Length + $paragraph.Length + 2) -le $maxChunkSize) {
                $currentChunk += "`n`n$paragraph"
            } else {
                if ($currentChunk.Length -gt 0) {
                    $chunks += $currentChunk.Trim()
                }
                $currentChunk = $paragraph
            }
        }

        if ($currentChunk.Length -gt 0) {
            $chunks += $currentChunk.Trim()
        }
    }

    Write-Host "Document split into $($chunks.Count) chunks for analysis" -ForegroundColor $CYAN

    # Analyze each chunk and combine results
    $allEvents = @()
    $allSentiments = @()
    $allEntities = @()
    $chunkNum = 1

    foreach ($chunk in $chunks) {
        Write-Host "Analyzing chunk $chunkNum of $($chunks.Count)..." -ForegroundColor $CYAN

        # Extract events and timeline
        $events = Extract-Events -Text $chunk -ChunkId $chunkNum
        if ($events -and $events.Count -gt 0) {
            $allEvents += $events
        }

        # Extract sentiment analysis
        $sentiments = Analyze-Sentiment -Text $chunk -ChunkId $chunkNum
        if ($sentiments -and $sentiments.Count -gt 0) {
            $allSentiments += $sentiments
        }

        # Extract entities (people, organizations, locations)
        $entities = Extract-Entities -Text $chunk -ChunkId $chunkNum
        if ($entities -and $entities.Count -gt 0) {
            $allEntities += $entities
        }

        $chunkNum++
    }

    # Sort events by date
    $allEvents = $allEvents | Sort-Object -Property Date

    # Generate output files
    $outputBaseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

    # Save events timeline
    $timelinePath = Join-Path $OutputPath "${outputBaseName}_timeline.csv"
    $allEvents | Export-Csv -Path $timelinePath -NoTypeInformation -Encoding UTF8

    # Save sentiment analysis
    $sentimentPath = Join-Path $OutputPath "${outputBaseName}_sentiment.csv"
    $allSentiments | Export-Csv -Path $sentimentPath -NoTypeInformation -Encoding UTF8

    # Save entities
    $entitiesPath = Join-Path $OutputPath "${outputBaseName}_entities.csv"
    $allEntities | Export-Csv -Path $entitiesPath -NoTypeInformation -Encoding UTF8

    # Generate summary report
    Generate-SummaryReport -Events $allEvents -Sentiments $allSentiments -Entities $allEntities -OutputPath (Join-Path $OutputPath "${outputBaseName}_summary_report.txt")

    # Generate visualizations if requested
    if (-not $NoVisualization) {
        Generate-Visualizations -Events $allEvents -Sentiments $allSentiments -Entities $allEntities -OutputPath $OutputPath -BaseName $outputBaseName
    }

    Write-Host "Analysis complete. Results saved to: $OutputPath" -ForegroundColor $GREEN

    return @{
        Events = $allEvents
        Sentiments = $allSentiments
        Entities = $allEntities
        OutputPath = $OutputPath
    }
}

# Extract events and timeline from text
function Extract-Events {
    param (
        [string]$Text,
        [int]$ChunkId
    )

    Write-Host "Extracting events and timeline from text (chunk $ChunkId)..." -ForegroundColor $CYAN

    $promptTemplate = @"
You are a legal document analyzer specializing in extracting events, dates, and factual information.
EXTRACT ALL EVENTS with dates from the following legal document text.
Focus exclusively on factual information, not opinions or allegations without evidence.

For each event, provide:
1. The exact date in YYYY-MM-DD format (estimate if only partial date is given)
2. The event description (factual, objective, without interpretation)
3. The event type (FILING, HEARING, TESTIMONY, EVIDENCE, MOTION, RULING, OTHER)
4. Any person names involved in the event
5. Any location information

If dates are ambiguous or incomplete, use the following format rules:
- If only month and day are provided, assume the current year
- If only month and year are provided, use the first day of the month
- If only year is provided, use January 1 of that year
- If no date is provided but sequencing is clear, mark as "UNDATED"

Format your response ONLY as a JSON array with the following fields:
[
  {
    "date": "YYYY-MM-DD or UNDATED",
    "description": "factual description of the event",
    "event_type": "one of the event types listed above",
    "persons": ["name1", "name2"],
    "location": "location information if available",
    "confidence": 0-100 (how confident are you this is a distinct factual event)
  },
  ...
]

DOCUMENT TEXT:
$Text
"@

    try {
        $modelRunnerEndpoint = "http://model-runner.docker.internal/engines/v1/chat/completions"

        $requestBody = @{
            model = $ModelType
            messages = @(
                @{
                    role = "system"
                    content = "You are a specialized legal document analyzer that extracts factual event information. Return ONLY valid JSON."
                },
                @{
                    role = "user"
                    content = $promptTemplate
                }
            )
            temperature = 0.1  # Low temperature for factual extraction
            top_p = 0.9
            max_tokens = 4000
            response_format = @{
                type = "json_object"
            }
        }

        $requestJson = $requestBody | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $modelRunnerEndpoint -Method Post -Body $requestJson -ContentType "application/json"

        $jsonContent = $response.choices[0].message.content

        # Parse and clean up the JSON response
        try {
            # Sometimes the model might wrap the array in an object
            if ($jsonContent -match '^\s*\{.*\}\s*$') {
                $jsonObj = $jsonContent | ConvertFrom-Json

                # Try to find the array property
                $arrayProps = $jsonObj.PSObject.Properties | Where-Object { $_.Value -is [Array] }
                if ($arrayProps) {
                    $events = $arrayProps[0].Value
                } else {
                    # Try to extract array from string property containing JSON
                    $stringProps = $jsonObj.PSObject.Properties | Where-Object { $_.Value -is [String] -and $_.Value -match '^\s*\[.*\]\s*$' }
                    if ($stringProps) {
                        $events = $stringProps[0].Value | ConvertFrom-Json
                    } else {
                        Write-Host "Unable to parse events array from response" -ForegroundColor $RED
                        return @()
                    }
                }
            } else {
                # Should be a direct array
                $events = $jsonContent | ConvertFrom-Json
            }

            # Convert to proper objects
            $outputEvents = @()
            foreach ($event in $events) {
                # Convert dates to proper format
                $dateString = if ($event.date -and $event.date -ne "UNDATED") {
                    try {
                        [DateTime]::Parse($event.date).ToString("yyyy-MM-dd")
                    } catch {
                        "UNDATED"
                    }
                } else {
                    "UNDATED"
                }

                $outputEvents += [PSCustomObject]@{
                    Date = $dateString
                    Description = $event.description
                    EventType = $event.event_type
                    Persons = if ($event.persons -is [Array]) { $event.persons -join "; " } else { $event.persons }
                    Location = $event.location
                    Confidence = [int]$event.confidence
                    ChunkId = $ChunkId
                }
            }

            Write-Host "Extracted $($outputEvents.Count) events" -ForegroundColor $GREEN
            return $outputEvents

        } catch {
            Write-Host "Error parsing JSON response: $_" -ForegroundColor $RED
            Write-Host "Raw response: $jsonContent" -ForegroundColor $RED
            return @()
        }

    } catch {
        Write-Host "Error extracting events from document: $_" -ForegroundColor $RED
        return @()
    }
}

# Analyze sentiment in text
function Analyze-Sentiment {
    param (
        [string]$Text,
        [int]$ChunkId
    )

    Write-Host "Analyzing sentiment in text (chunk $ChunkId)..." -ForegroundColor $CYAN

    $promptTemplate = @"
You are a neutral sentiment analyzer for legal documents. Your task is to identify paragraphs containing subjective language,
emotional content, or potential bias in the document. Analyze the document paragraph by paragraph.

For each paragraph or significant section that contains non-neutral language:
1. Extract the actual text
2. Determine if the language demonstrates positive or negative sentiment
3. Rate the sentiment intensity (1-5 scale)
4. Identify the specific words or phrases that contribute to this sentiment
5. Note any potential bias indicators

Format your response ONLY as a JSON array with the following fields:
[
  {
    "paragraph_text": "The exact text of the paragraph or statement",
    "sentiment": "POSITIVE, NEGATIVE, or NEUTRAL",
    "intensity": 1-5 (with 5 being strongest),
    "key_phrases": ["specific phrase 1", "specific phrase 2"],
    "bias_indicators": ["indicator 1", "indicator 2"] or [],
    "objective_alternative": "A more neutral/objective way to phrase this"
  },
  ...
]

Only include paragraphs with non-neutral sentiment. Do not analyze purely factual statements with no emotional content.

DOCUMENT TEXT:
$Text
"@

    try {
        $modelRunnerEndpoint = "http://model-runner.docker.internal/engines/v1/chat/completions"

        $requestBody = @{
            model = $ModelType
            messages = @(
                @{
                    role = "system"
                    content = "You are a specialized sentiment analyzer for legal documents. Return ONLY valid JSON."
                },
                @{
                    role = "user"
                    content = $promptTemplate
                }
            )
            temperature = 0.1
            top_p = 0.9
            max_tokens = 4000
            response_format = @{
                type = "json_object"
            }
        }

        $requestJson = $requestBody | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $modelRunnerEndpoint -Method Post -Body $requestJson -ContentType "application/json"

        $jsonContent = $response.choices[0].message.content

        # Parse and clean up the JSON response
        try {
            # Sometimes the model might wrap the array in an object
            if ($jsonContent -match '^\s*\{.*\}\s*$') {
                $jsonObj = $jsonContent | ConvertFrom-Json

                # Try to find the array property
                $arrayProps = $jsonObj.PSObject.Properties | Where-Object { $_.Value -is [Array] }
                if ($arrayProps) {
                    $sentiments = $arrayProps[0].Value
                } else {
                    # Try to extract array from string property containing JSON
                    $stringProps = $jsonObj.PSObject.Properties | Where-Object { $_.Value -is [String] -and $_.Value -match '^\s*\[.*\]\s*$' }
                    if ($stringProps) {
                        $sentiments = $stringProps[0].Value | ConvertFrom-Json
                    } else {
                        Write-Host "Unable to parse sentiment array from response" -ForegroundColor $RED
                        return @()
                    }
                }
            } else {
                # Should be a direct array
                $sentiments = $jsonContent | ConvertFrom-Json
            }

            # Convert to proper objects
            $outputSentiments = @()
            foreach ($sentiment in $sentiments) {
                $outputSentiments += [PSCustomObject]@{
                    ParagraphText = if ($sentiment.paragraph_text.Length -gt 150) { $sentiment.paragraph_text.Substring(0, 147) + "..." } else { $sentiment.paragraph_text }
                    FullText = $sentiment.paragraph_text
                    Sentiment = $sentiment.sentiment
                    Intensity = [int]$sentiment.intensity
                    KeyPhrases = if ($sentiment.key_phrases -is [Array]) { $sentiment.key_phrases -join "; " } else { $sentiment.key_phrases }
                    BiasIndicators = if ($sentiment.bias_indicators -is [Array]) { $sentiment.bias_indicators -join "; " } else { $sentiment.bias_indicators }
                    ObjectiveAlternative = $sentiment.objective_alternative
                    ChunkId = $ChunkId
                }
            }

            Write-Host "Analyzed sentiment in $($outputSentiments.Count) paragraphs" -ForegroundColor $GREEN
            return $outputSentiments

        } catch {
            Write-Host "Error parsing JSON sentiment response: $_" -ForegroundColor $RED
            Write-Host "Raw response: $jsonContent" -ForegroundColor $RED
            return @()
        }

    } catch {
        Write-Host "Error analyzing sentiment in document: $_" -ForegroundColor $RED
        return @()
    }
}

# Extract entities from text (people, organizations, locations)
function Extract-Entities {
    param (
        [string]$Text,
        [int]$ChunkId
    )

    Write-Host "Extracting entities from text (chunk $ChunkId)..." -ForegroundColor $CYAN

    $promptTemplate = @"
You are a legal document entity extractor. Extract all named entities from the following legal document text.
Focus on identifying:
1. PERSON: Individual names (parties, witnesses, attorneys, judges)
2. ORGANIZATION: Companies, government agencies, courts, departments
3. LOCATION: Addresses, cities, states, locations mentioned
4. ROLE: Professional roles or titles (judge, attorney, officer)
5. IDENTIFIER: Case numbers, docket numbers, file references

Format your response ONLY as a JSON array with the following fields:
[
  {
    "text": "the exact entity text",
    "type": "PERSON, ORGANIZATION, LOCATION, ROLE, or IDENTIFIER",
    "context": "brief phrase showing context where entity appears",
    "frequency": number (how many times this entity appears in text),
    "aliases": ["other names for same entity"] or []
  },
  ...
]

Group identical entities and count their frequency. For persons, try to identify aliases or variations of the same name.

DOCUMENT TEXT:
$Text
"@

    try {
        $modelRunnerEndpoint = "http://model-runner.docker.internal/engines/v1/chat/completions"

        $requestBody = @{
            model = $ModelType
            messages = @(
                @{
                    role = "system"
                    content = "You are a specialized entity extractor for legal documents. Return ONLY valid JSON."
                },
                @{
                    role = "user"
                    content = $promptTemplate
                }
            )
            temperature = 0.1
            top_p = 0.9
            max_tokens = 4000
            response_format = @{
                type = "json_object"
            }
        }

        $requestJson = $requestBody | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $modelRunnerEndpoint -Method Post -Body $requestJson -ContentType "application/json"

        $jsonContent = $response.choices[0].message.content

        # Parse and clean up the JSON response
        try {
            # Sometimes the model might wrap the array in an object
            if ($jsonContent -match '^\s*\{.*\}\s*$') {
                $jsonObj = $jsonContent | ConvertFrom-Json

                # Try to find the array property
                $arrayProps = $jsonObj.PSObject.Properties | Where-Object { $_.Value -is [Array] }
                if ($arrayProps) {
                    $entities = $arrayProps[0].Value
                } else {
                    # Try to extract array from string property containing JSON
                    $stringProps = $jsonObj.PSObject.Properties | Where-Object { $_.Value -is [String] -and $_.Value -match '^\s*\[.*\]\s*$' }
                    if ($stringProps) {
                        $entities = $stringProps[0].Value | ConvertFrom-Json
                    } else {
                        Write-Host "Unable to parse entities array from response" -ForegroundColor $RED
                        return @()
                    }
                }
            } else {
                # Should be a direct array
                $entities = $jsonContent | ConvertFrom-Json
            }

            # Convert to proper objects
            $outputEntities = @()
            foreach ($entity in $entities) {
                $outputEntities += [PSCustomObject]@{
                    Text = $entity.text
                    Type = $entity.type
                    Context = $entity.context
                    Frequency = [int]$entity.frequency
                    Aliases = if ($entity.aliases -is [Array]) { $entity.aliases -join "; " } else { $entity.aliases }
                    ChunkId = $ChunkId
                }
            }

            Write-Host "Extracted $($outputEntities.Count) entities" -ForegroundColor $GREEN
            return $outputEntities

        } catch {
            Write-Host "Error parsing JSON entities response: $_" -ForegroundColor $RED
            Write-Host "Raw response: $jsonContent" -ForegroundColor $RED
            return @()
        }

    } catch {
        Write-Host "Error extracting entities from document: $_" -ForegroundColor $RED
        return @()
    }
}

# Generate summary report
function Generate-SummaryReport {
    param (
        [array]$Events,
        [array]$Sentiments,
        [array]$Entities,
        [string]$OutputPath
    )

    Write-Host "Generating summary report..." -ForegroundColor $CYAN

    $reportBuilder = New-Object System.Text.StringBuilder

    # Add header
    $reportBuilder.AppendLine("==========================================") | Out-Null
    $reportBuilder.AppendLine("LEGAL DOCUMENT ANALYSIS SUMMARY REPORT") | Out-Null
    $reportBuilder.AppendLine("==========================================") | Out-Null
    $reportBuilder.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
    $reportBuilder.AppendLine("") | Out-Null

    # Timeline summary
    $reportBuilder.AppendLine("## TIMELINE SUMMARY") | Out-Null
    $reportBuilder.AppendLine("------------------------------------------") | Out-Null

    if ($Events -and $Events.Count -gt 0) {
        $reportBuilder.AppendLine("Total events identified: $($Events.Count)") | Out-Null

        # Group by event type
        $eventTypeGroups = $Events | Group-Object -Property EventType
        $reportBuilder.AppendLine("") | Out-Null
        $reportBuilder.AppendLine("Events by type:") | Out-Null
        foreach ($group in $eventTypeGroups) {
            $reportBuilder.AppendLine("- $($group.Name): $($group.Count) events") | Out-Null
        }

        # Date range
        $datedEvents = $Events | Where-Object { $_.Date -ne "UNDATED" }
        if ($datedEvents -and $datedEvents.Count -gt 0) {
            $minDate = ($datedEvents | Sort-Object -Property Date | Select-Object -First 1).Date
            $maxDate = ($datedEvents | Sort-Object -Property Date -Descending | Select-Object -First 1).Date
            $reportBuilder.AppendLine("") | Out-Null
            $reportBuilder.AppendLine("Date range: $minDate to $maxDate") | Out-Null
        }

        # List of key events (high confidence)
        $keyEvents = $Events | Where-Object { $_.Confidence -ge 80 } | Sort-Object -Property Date
        if ($keyEvents -and $keyEvents.Count -gt 0) {
            $reportBuilder.AppendLine("") | Out-Null
            $reportBuilder.AppendLine("KEY EVENTS (high confidence):") | Out-Null
            foreach ($event in $keyEvents) {
                $dateDisplay = if ($event.Date -eq "UNDATED") { "[No date]" } else { $event.Date }
                $reportBuilder.AppendLine("- $dateDisplay: $($event.Description)") | Out-Null
            }
        }
    } else {
        $reportBuilder.AppendLine("No timeline events identified.") | Out-Null
    }

    $reportBuilder.AppendLine("") | Out-Null

    # Sentiment analysis summary
    $reportBuilder.AppendLine("## SENTIMENT ANALYSIS") | Out-Null
    $reportBuilder.AppendLine("------------------------------------------") | Out-Null

    if ($Sentiments -and $Sentiments.Count -gt 0) {
        $positiveSentiments = $Sentiments | Where-Object { $_.Sentiment -eq "POSITIVE" }
        $negativeSentiments = $Sentiments | Where-Object { $_.Sentiment -eq "NEGATIVE" }
        $neutralSentiments = $Sentiments | Where-Object { $_.Sentiment -eq "NEUTRAL" }

        $reportBuilder.AppendLine("Total analyzed segments: $($Sentiments.Count)") | Out-Null
        $reportBuilder.AppendLine("- Positive: $($positiveSentiments.Count)") | Out-Null
        $reportBuilder.AppendLine("- Negative: $($negativeSentiments.Count)") | Out-Null
        $reportBuilder.AppendLine("- Neutral: $($neutralSentiments.Count)") | Out-Null

        # High intensity segments
        $highIntensitySentiments = $Sentiments | Where-Object { $_.Intensity -ge 4 } | Sort-Object -Property Intensity -Descending
        if ($highIntensitySentiments -and $highIntensitySentiments.Count -gt 0) {
            $reportBuilder.AppendLine("") | Out-Null
            $reportBuilder.AppendLine("HIGH INTENSITY LANGUAGE SEGMENTS:") | Out-Null
            foreach ($sentiment in $highIntensitySentiments | Select-Object -First 5) {
                $reportBuilder.AppendLine("- [$($sentiment.Sentiment), Intensity: $($sentiment.Intensity)] $($sentiment.ParagraphText)") | Out-Null
                $reportBuilder.AppendLine("  Key phrases: $($sentiment.KeyPhrases)") | Out-Null
                if ($sentiment.BiasIndicators) {
                    $reportBuilder.AppendLine("  Bias indicators: $($sentiment.BiasIndicators)") | Out-Null
                }
                $reportBuilder.AppendLine("") | Out-Null
            }
        }

        # Bias indicators summary
        $segmentsWithBias = $Sentiments | Where-Object { $_.BiasIndicators }
        if ($segmentsWithBias -and $segmentsWithBias.Count -gt 0) {
            $reportBuilder.AppendLine("POTENTIAL BIAS INDICATORS:") | Out-Null
            $reportBuilder.AppendLine("$($segmentsWithBias.Count) segments contain potential bias indicators.") | Out-Null
        }
    } else {
        $reportBuilder.AppendLine("No sentiment analysis performed.") | Out-Null
    }

    $reportBuilder.AppendLine("") | Out-Null

    # Entity summary
    $reportBuilder.AppendLine("## ENTITY ANALYSIS") | Out-Null
    $reportBuilder.AppendLine("------------------------------------------") | Out-Null

    if ($Entities -and $Entities.Count -gt 0) {
        # Group by entity type
        $entityTypeGroups = $Entities | Group-Object -Property Type

        foreach ($group in $entityTypeGroups) {
            $reportBuilder.AppendLine("$($group.Name) entities: $($group.Count)") | Out-Null

            # List top entities by frequency
            $topEntities = $group.Group | Sort-Object -Property Frequency -Descending | Select-Object -First 10
            $reportBuilder.AppendLine("Top $($group.Name) by frequency:") | Out-Null
            foreach ($entity in $topEntities) {
                $aliasInfo = if ($entity.Aliases) { " (also: $($entity.Aliases))" } else { "" }
                $reportBuilder.AppendLine("- $($entity.Text)$aliasInfo: mentioned $($entity.Frequency) times") | Out-Null
            }
            $reportBuilder.AppendLine("") | Out-Null
        }
    } else {
        $reportBuilder.AppendLine("No entities identified.") | Out-Null
    }

    # Write the report to file
    Set-Content -Path $OutputPath -Value $reportBuilder.ToString() -Encoding UTF8
    Write-Host "Summary report generated: $OutputPath" -ForegroundColor $GREEN
}

# Generate visualizations
function Generate-Visualizations {
    param (
        [array]$Events,
        [array]$Sentiments,
        [array]$Entities,
        [string]$OutputPath,
        [string]$BaseName
    )

    Write-Host "Generating visualizations..." -ForegroundColor $CYAN

    # Timeline visualization with Excel
    try {
        # Only proceed if we have events with dates
        $datedEvents = $Events | Where-Object { $_.Date -ne "UNDATED" }
        if ($datedEvents -and $datedEvents.Count -gt 0) {
            $timelineExcelPath = Join-Path $OutputPath "${BaseName}_timeline_visualization.xlsx"

            # Create Excel package
            $excel = New-Object -TypeName OfficeOpenXml.ExcelPackage
            $workbook = $excel.Workbook

            # Add timeline worksheet
            $timelineSheet = $workbook.Worksheets.Add("Timeline")

            # Add headers
            $timelineSheet.Cells["A1"].Value = "Date"
            $timelineSheet.Cells["B1"].Value = "Event Type"
            $timelineSheet.Cells["C1"].Value = "Description"
            $timelineSheet.Cells["D1"].Value = "Persons"
            $timelineSheet.Cells["E1"].Value = "Location"
            $timelineSheet.Cells["F1"].Value = "Confidence"

            # Style headers
            $headerRange = $timelineSheet.Cells["A1:F1"]
            $headerRange.Style.Font.Bold = $true
            $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $headerRange.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightGray)

            # Add data
            $row = 2
            foreach ($event in ($datedEvents | Sort-Object -Property Date)) {
                $timelineSheet.Cells["A$row"].Value = $event.Date
                $timelineSheet.Cells["B$row"].Value = $event.EventType
                $timelineSheet.Cells["C$row"].Value = $event.Description
                $timelineSheet.Cells["D$row"].Value = $event.Persons
                $timelineSheet.Cells["E$row"].Value = $event.Location
                $timelineSheet.Cells["F$row"].Value = $event.Confidence

                # Conditional formatting based on event type
                switch ($event.EventType) {
                    "FILING" {
                        $timelineSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Blue)
                    }
                    "HEARING" {
                        $timelineSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Green)
                    }
                    "TESTIMONY" {
                        $timelineSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Purple)
                    }
                    "EVIDENCE" {
                        $timelineSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Orange)
                    }
                    "RULING" {
                        $timelineSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Red)
                    }
                }

                # Conditional formatting based on confidence
                if ($event.Confidence -ge 80) {
                    $timelineSheet.Cells["F$row"].Style.Font.Bold = $true
                } elseif ($event.Confidence -lt 50) {
                    $timelineSheet.Cells["F$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)
                }

                $row++
            }

            # Auto size columns
            $timelineSheet.Cells[$timelineSheet.Dimension.Address].AutoFitColumns()

            # Add sentiment analysis worksheet if we have data
            if ($Sentiments -and $Sentiments.Count -gt 0) {
                $sentimentSheet = $workbook.Worksheets.Add("Sentiment Analysis")

                # Add headers
                $sentimentSheet.Cells["A1"].Value = "Sentiment"
                $sentimentSheet.Cells["B1"].Value = "Intensity"
                $sentimentSheet.Cells["C1"].Value = "Text"
                $sentimentSheet.Cells["D1"].Value = "Key Phrases"
                $sentimentSheet.Cells["E1"].Value = "Bias Indicators"

                # Style headers
                $headerRange = $sentimentSheet.Cells["A1:E1"]
                $headerRange.Style.Font.Bold = $true
                $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                $headerRange.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightGray)

                # Add data
                $row = 2
                foreach ($sentiment in ($Sentiments | Sort-Object -Property Intensity -Descending)) {
                    $sentimentSheet.Cells["A$row"].Value = $sentiment.Sentiment
                    $sentimentSheet.Cells["B$row"].Value = $sentiment.Intensity
                    $sentimentSheet.Cells["C$row"].Value = $sentiment.ParagraphText
                    $sentimentSheet.Cells["D$row"].Value = $sentiment.KeyPhrases
                    $sentimentSheet.Cells["E$row"].Value = $sentiment.BiasIndicators

                    # Conditional formatting based on sentiment
                    switch ($sentiment.Sentiment) {
                        "POSITIVE" {
                            $sentimentSheet.Cells["A$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Green)
                        }
                        "NEGATIVE" {
                            $sentimentSheet.Cells["A$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Red)
                        }
                        "NEUTRAL" {
                            $sentimentSheet.Cells["A$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)
                        }
                    }

                    # Conditional formatting based on intensity
                    if ($sentiment.Intensity -ge 4) {
                        $sentimentSheet.Cells["B$row"].Style.Font.Bold = $true
                        $sentimentSheet.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Red)
                    }

                    $row++
                }

                # Auto size columns
                $sentimentSheet.Cells[$sentimentSheet.Dimension.Address].AutoFitColumns()
            }

            # Add entities worksheet if we have data
            if ($Entities -and $Entities.Count -gt 0) {
                $entitySheet = $workbook.Worksheets.Add("Entities")

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
                    $entitySheet.Cells["E$row"].Value = $entity.Aliases

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

                    # Highlight high frequency entities
                    if ($entity.Frequency -ge 10) {
                        $entitySheet.Cells["C$row"].Style.Font.Bold = $true
                    }

                    $row++
                }

                # Auto size columns
                $entitySheet.Cells[$entitySheet.Dimension.Address].AutoFitColumns()
            }

            # Save the Excel file
            $excel.SaveAs((New-Object System.IO.FileInfo($timelineExcelPath)))
            $excel.Dispose()

            Write-Host "Timeline visualization created: $timelineExcelPath" -ForegroundColor $GREEN
        } else {
            Write-Host "No dated events found for timeline visualization" -ForegroundColor $YELLOW
        }
    } catch {
        Write-Host "Error generating visualizations: $_" -ForegroundColor $RED
    }
}

# Process a single file
function Process-SingleFile {
    param (
        [string]$FilePath
    )

    Write-Host "Processing file: $FilePath" -ForegroundColor $CYAN

    # Create output folder
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $outputPath = Join-Path $OutputFolder ([System.IO.Path]::GetFileNameWithoutExtension($fileName))

    if (-not (Test-Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    }

    # Extract text from document
    $text = Extract-DocumentText -FilePath $FilePath

    if (-not $text) {
        Write-Host "Failed to extract text from document. Aborting analysis." -ForegroundColor $RED
        return $false
    }

    # Analyze the document
    $analysisResults = Analyze-Document -Text $text -FileName $fileName -OutputPath $outputPath

    if ($analysisResults) {
        Write-Host "Document processing complete. Results saved to: $outputPath" -ForegroundColor $GREEN

        # Open the output folder
        Invoke-Item $outputPath

        return $true
    } else {
        Write-Host "Document analysis failed." -ForegroundColor $RED
        return $false
    }
}

# Watch folder for new files
function Watch-FolderForDocuments {
    param (
        [string]$FolderPath
    )

    Write-Host "Watching folder for new documents: $FolderPath" -ForegroundColor $CYAN
    Write-Host "Press Ctrl+C to stop watching" -ForegroundColor $CYAN

    # Create the folder if it doesn't exist
    if (-not (Test-Path $FolderPath)) {
        New-Item -ItemType Directory -Path $FolderPath -Force | Out-Null
        Write-Host "Created watch folder: $FolderPath" -ForegroundColor $GREEN
    }

    # Create a FileSystemWatcher
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $FolderPath
    $watcher.IncludeSubdirectories = $false
    $watcher.EnableRaisingEvents = $true

    # Define event handlers
    $action = {
        $path = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType
        $fileName = [System.IO.Path]::GetFileName($path)
        $extension = [System.IO.Path]::GetExtension($path).ToLower()

        if ($changeType -eq 'Created' -and ($extension -eq '.pdf' -or $extension -eq '.docx' -or $extension -eq '.txt')) {
            Write-Host "`nNew document detected: $fileName" -ForegroundColor $CYAN

            # Wait a moment to ensure the file is fully written
            Start-Sleep -Seconds 2

            # Process the file
            & $processSingleFile $path
        }
    }

    # Register event handlers
    $handlers = . {
        Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action
    }

    try {
        Write-Host "Watching for new documents. Supported formats: PDF, DOCX, TXT" -ForegroundColor $GREEN

        # Keep the script running
        while ($true) {
            Start-Sleep -Seconds 1
        }
    } finally {
        # Clean up event handlers when script is stopped
        $handlers | ForEach-Object {
            Unregister-Event -SourceIdentifier $_.Name
        }

        $watcher.Dispose()
        Write-Host "Stopped watching folder" -ForegroundColor $YELLOW
    }
}

# Main script
try {
    # Create script scope variable for the process function to be used in the file watcher
    $script:processSingleFile = ${function:Process-SingleFile}.ToString()

    # Create output folder if it doesn't exist
    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }    # Load required modules
    Load-RequiredModules

    # Verify Docker Model Runner
    $modelRunnerAvailable = Test-DockerModelRunner

    if (-not $modelRunnerAvailable) {
        Write-Host "Docker Model Runner is not available or the requested model is not accessible. Please fix the issues before proceeding." -ForegroundColor $RED
        exit 1
    }

    # Process based on parameter set
    if ($PSCmdlet.ParameterSetName -eq "SingleFile") {
        if ($InputFile) {
            Process-SingleFile -FilePath $InputFile
        } else {
            Write-Host "No input file specified. Please specify an input file using -InputFile parameter." -ForegroundColor $RED
            exit 1
        }
    } elseif ($PSCmdlet.ParameterSetName -eq "Watch") {
        if ($WatchFolder) {
            Watch-FolderForDocuments -FolderPath $WatchFolder
        } else {
            Write-Host "No watch folder specified. Please specify a folder to watch using -WatchFolder parameter." -ForegroundColor $RED
            exit 1
        }
    } else {
        Write-Host "Please specify either -InputFile or -WatchFolder parameter." -ForegroundColor $RED
        exit 1
    }
} catch {
    Write-Host "Error processing documents: $_" -ForegroundColor $RED
    Write-Host $_.ScriptStackTrace -ForegroundColor $RED
    exit 1
}
