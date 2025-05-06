# Generate-TestDocuments.ps1
<#
.SYNOPSIS
    Generates test legal documents for testing the legal document analysis system.

.DESCRIPTION
    Creates sample PDF, DOCX, and TXT files containing mock court docket information
    for testing the legal document analysis system.

.PARAMETER OutputFolder
    Path where test documents will be saved. Default is "./test-documents".

.PARAMETER Count
    Number of test documents to generate for each format. Default is 1.

.EXAMPLE
    .\Generate-TestDocuments.ps1 -OutputFolder "C:\Test-Data" -Count 3
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = "./test-documents",

    [Parameter(Mandatory = $false)]
    [int]$Count = 1
)

# Create output folder if it doesn't exist
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    Write-Host "Created output folder: $OutputFolder" -ForegroundColor Green
}

# Sample court case data
$caseTypes = @("Domestic Violence", "Protection Order", "Custody", "Divorce", "Child Support")
$parties = @(
    @{First = "John"; Last = "Smith"; Role = "Plaintiff"},
    @{First = "Jane"; Last = "Smith"; Role = "Defendant"},
    @{First = "Michael"; Last = "Johnson"; Role = "Plaintiff"},
    @{First = "Sarah"; Last = "Johnson"; Role = "Defendant"},
    @{First = "Robert"; Last = "Williams"; Role = "Plaintiff"},
    @{First = "Lisa"; Last = "Williams"; Role = "Defendant"}
)
$attorneys = @(
    @{Name = "David Wilson"; Firm = "Wilson & Associates"; Role = "Plaintiff's Attorney"},
    @{Name = "Emily Baker"; Firm = "Legal Aid Society"; Role = "Defendant's Attorney"},
    @{Name = "Thomas Reynolds"; Firm = "Reynolds Law Group"; Role = "Plaintiff's Attorney"},
    @{Name = "Rebecca Martinez"; Firm = "Public Defender's Office"; Role = "Defendant's Attorney"}
)
$judges = @(
    "Hon. James Robertson",
    "Hon. Patricia Miller",
    "Hon. Richard Davis",
    "Hon. Sandra Thompson"
)
$courts = @(
    "Family Court, County of Richmond",
    "Supreme Court, County of Kings",
    "Family Court, County of New York",
    "Superior Court, County of Essex"
)
$actions = @(
    "MOTION filed",
    "ORDER issued",
    "HEARING scheduled",
    "CONTINUANCE granted",
    "PETITION filed",
    "RESPONSE filed",
    "EVIDENCE submitted",
    "TESTIMONY taken",
    "RULING issued",
    "CASE closed"
)
$months = @("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")

# Function to generate random date within past 2 years
function Get-RandomDate {
    $startDate = (Get-Date).AddYears(-2)
    $endDate = Get-Date
    $timeSpan = New-TimeSpan -Start $startDate -End $endDate
    $randomDays = Get-Random -Minimum 0 -Maximum $timeSpan.TotalDays
    $randomDate = $startDate.AddDays($randomDays)
    return $randomDate
}

# Function to generate random case number
function Get-RandomCaseNumber {
    $year = Get-Random -Minimum 2018 -Maximum 2024
    $number = Get-Random -Minimum 1000 -Maximum 9999
    return "DV-$year-$number"
}

# Function to generate random sentiment text
function Get-RandomSentimentText {
    $positive = @(
        "The court found sufficient evidence to support the plaintiff's claims.",
        "Testimony was deemed credible and consistent with documentary evidence.",
        "The judge noted the defendant's cooperation with court orders.",
        "The witness provided clear and convincing testimony in support of the allegations."
    )

    $negative = @(
        "The defendant failed to appear despite proper notice.",
        "The court found the testimony to be inconsistent with previous statements.",
        "Evidence suggests a pattern of intimidation and threats.",
        "The court expressed concern over repeated violations of the temporary order."
    )

    $neutral = @(
        "The case was continued to allow parties to complete discovery.",
        "Both parties agreed to meet with the court-appointed mediator.",
        "The court scheduled a follow-up hearing to review compliance.",
        "Documentation was submitted by both parties for court review."
    )

    $sentiment = Get-Random -InputObject @("positive", "negative", "neutral")

    switch ($sentiment) {
        "positive" { return Get-Random -InputObject $positive }
        "negative" { return Get-Random -InputObject $negative }
        "neutral" { return Get-Random -InputObject $neutral }
    }
}

# Generate a full test document
function Generate-DocumentContent {
    $caseType = Get-Random -InputObject $caseTypes
    $caseNumber = Get-RandomCaseNumber
    $court = Get-Random -InputObject $courts
    $judge = Get-Random -InputObject $judges
    $plaintiff = Get-Random -InputObject ($parties | Where-Object { $_.Role -eq "Plaintiff" })
    $defendant = Get-Random -InputObject ($parties | Where-Object { $_.Role -eq "Defendant" })
    $plaintiffAttorney = Get-Random -InputObject ($attorneys | Where-Object { $_.Role -eq "Plaintiff's Attorney" })
    $defendantAttorney = Get-Random -InputObject ($attorneys | Where-Object { $_.Role -eq "Defendant's Attorney" })

    # Generate random events for timeline (between 5-15 events)
    $eventCount = Get-Random -Minimum 5 -Maximum 15
    $events = @()
    $startDate = Get-RandomDate

    for ($i = 0; $i -lt $eventCount; $i++) {
        $eventDate = $startDate.AddDays($i * (Get-Random -Minimum 3 -Maximum 30))
        $action = Get-Random -InputObject $actions
        $description = Get-RandomSentimentText

        $events += @{
            Date = $eventDate
            FormattedDate = $eventDate.ToString("MMMM d, yyyy")
            Action = $action
            Description = $description
        }
    }

    # Sort events by date
    $events = $events | Sort-Object -Property Date

    # Build document content
    $content = @"
===================================================================
COURT DOCKET INFORMATION
===================================================================

CASE NUMBER: $caseNumber
CASE TYPE: $caseType
FILED: $($events[0].FormattedDate)
COURT: $court
PRESIDING JUDGE: $judge

-------------------------------------------------------------------
PARTIES
-------------------------------------------------------------------

PLAINTIFF: $($plaintiff.First) $($plaintiff.Last)
DEFENDANT: $($defendant.First) $($defendant.Last)

PLAINTIFF'S ATTORNEY: $($plaintiffAttorney.Name), $($plaintiffAttorney.Firm)
DEFENDANT'S ATTORNEY: $($defendantAttorney.Name), $($defendantAttorney.Firm)

-------------------------------------------------------------------
DOCKET ENTRIES
-------------------------------------------------------------------

"@

    foreach ($event in $events) {
        $content += @"
$($event.FormattedDate): $($event.Action)
    $($event.Description)

"@
    }

    $content += @"
-------------------------------------------------------------------
CASE STATUS: $(if ($events[-1].Action -eq "CASE closed") { "CLOSED" } else { "OPEN" })
LAST UPDATED: $((Get-Date).ToString("MMMM d, yyyy"))
===================================================================
"@

    return $content
}

# Create test documents in TXT format
for ($i = 1; $i -le $Count; $i++) {
    $txtPath = Join-Path $OutputFolder "Test_Legal_Document_$i.txt"
    $content = Generate-DocumentContent
    $content | Out-File -FilePath $txtPath -Encoding utf8
    Write-Host "Created TXT test document: $txtPath" -ForegroundColor Cyan
}

# Check for Word COM object to create DOCX
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false

    for ($i = 1; $i -le $Count; $i++) {
        $docxPath = Join-Path $OutputFolder "Test_Legal_Document_$i.docx"
        $content = Generate-DocumentContent

        $doc = $word.Documents.Add()
        $doc.Content.Text = $content
        $doc.SaveAs([ref]$docxPath, [ref]16) # 16 = wdFormatDocumentDefault
        $doc.Close()

        Write-Host "Created DOCX test document: $docxPath" -ForegroundColor Cyan
    }

    $word.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
} catch {
    Write-Warning "Could not create DOCX files: $_"
    Write-Host "Microsoft Word may not be installed or accessible." -ForegroundColor Yellow
}

# Check for iTextSharp to create PDF
try {
    # Try to load the iTextSharp library
    Add-Type -Path (Join-Path $PSScriptRoot "lib\itextsharp.dll") -ErrorAction Stop

    for ($i = 1; $i -le $Count; $i++) {
        $pdfPath = Join-Path $OutputFolder "Test_Legal_Document_$i.pdf"
        $content = Generate-DocumentContent

        $document = New-Object iTextSharp.text.Document
        $writer = [iTextSharp.text.pdf.PdfWriter]::GetInstance($document, (New-Object System.IO.FileStream($pdfPath, [System.IO.FileMode]::Create)))
        $document.Open()

        $contentParagraph = New-Object iTextSharp.text.Paragraph($content)
        $document.Add($contentParagraph)

        $document.Close()
        $writer.Close()

        Write-Host "Created PDF test document: $pdfPath" -ForegroundColor Cyan
    }
} catch {
    Write-Warning "Could not create PDF files: $_"
    Write-Host "Try installing the iTextSharp library or use Word's 'Save As PDF' feature." -ForegroundColor Yellow

    # Try to use Word to save as PDF if available
    if ($word -ne $null) {
        try {
            $word = New-Object -ComObject Word.Application
            $word.Visible = $false

            for ($i = 1; $i -le $Count; $i++) {
                $docxPath = Join-Path $OutputFolder "Test_Legal_Document_$i.docx"
                $pdfPath = Join-Path $OutputFolder "Test_Legal_Document_$i.pdf"

                if (Test-Path $docxPath) {
                    $doc = $word.Documents.Open($docxPath)
                    $doc.SaveAs([ref]$pdfPath, [ref]17) # 17 = wdFormatPDF
                    $doc.Close()

                    Write-Host "Created PDF test document (via Word): $pdfPath" -ForegroundColor Cyan
                }
            }

            $word.Quit()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
        } catch {
            Write-Warning "Could not create PDF files using Word: $_"
        }
    }
}

Write-Host "Test document generation complete. Documents saved to: $OutputFolder" -ForegroundColor Green
