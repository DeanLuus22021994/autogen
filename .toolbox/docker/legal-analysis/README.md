# Legal Document Analysis System

This system is designed to analyze legal documents, specifically court docket information in domestic violence cases. It extracts events, performs sentiment analysis, and builds timelines without using external APIs, ensuring all processing happens locally.

## Features

- **Document Processing**: Support for PDF, DOCX, and TXT files
- **Event Extraction**: Identifies key events and dates from court documents
- **Timeline Generation**: Creates visual timelines based on extracted events
- **Sentiment Analysis**: Identifies language tone, bias, and emotional content
- **Entity Extraction**: Recognizes persons, organizations, locations, and roles
- **Local Processing**: Uses Docker Model Runner for AI processing without external API calls
- **Automatic Processing**: Monitors folders for new documents
- **Visualization**: Generates Excel reports and textual summaries

## Requirements

- Docker with Docker Model Runner
- PowerShell 7.0+
- Windows, Linux, or macOS with Docker support
- 8GB+ RAM recommended
- GPU with 4GB+ VRAM for optimal performance (optional)

## Quick Start

1. Set up the system:
   ```powershell
   cd c:\Projects\autogen\.toolbox\docker\legal-analysis
   .\Start-LegalAnalysisSystem.ps1 -GenerateTestDocuments
   ```

2. Process a document:
   ```powershell
   .\Process-LegalDocuments.ps1 -InputFile "path\to\document.pdf"
   ```

3. Access the dashboard at http://localhost:3000

## Installation

1. Ensure Docker is installed and running

2. Setup Docker Model Runner (if not already done):
   ```powershell
   cd c:\Projects\autogen
   .\Setup-DockerModelRunner.ps1
   ```

3. Start the legal analysis system:
   ```powershell
   cd c:\Projects\autogen\.toolbox\docker\legal-analysis
   .\Start-LegalAnalysisSystem.ps1
   ```

4. Configure VS Code integration (optional):
   ```powershell
   .\Set-LegalDocumentsTasks.ps1
   ```

## Usage

### Command Line

Process a single file:
```powershell
.\Process-LegalDocuments.ps1 -InputFile "path\to\document.pdf" -OutputFolder "path\to\output"
```

Watch a folder for new documents:
```powershell
.\Process-LegalDocuments.ps1 -WatchFolder "path\to\documents" -OutputFolder "path\to\output"
```

Generate test documents:
```powershell
.\Generate-TestDocuments.ps1 -OutputFolder "path\to\output" -Count 3
```

### VS Code Tasks

If you've run the `Set-LegalDocumentsTasks.ps1` script, you can use these VS Code tasks:

1. Press `Ctrl+Shift+P` and type "Tasks: Run Task"
2. Select one of the legal analysis tasks:
   - "Legal Analysis: Process Document" - Process a single document
   - "Legal Analysis: Watch Folder" - Monitor a folder for new documents
   - "Legal Analysis: Start Docker Stack" - Start the Docker services
   - "Legal Analysis: Generate Test Documents" - Create test documents

## Configuration

Edit the `legal-analysis-config.xml` file to customize:

- Model settings
- Document processing options
- Analysis module parameters
- Visualization preferences
- File monitoring settings
- Privacy settings

## Architecture

The system consists of the following components:

### PowerShell Scripts

- **Process-LegalDocuments.ps1**: Main script for processing documents
- **LegalDocumentAnalysis.psm1**: Core module with analysis functions
- **Start-LegalAnalysisSystem.ps1**: Script to configure and start services
- **Generate-TestDocuments.ps1**: Creates sample documents for testing
- **Set-LegalDocumentsTasks.ps1**: Configures VS Code integration

### Docker Containers

- **legal-analysis**: Main service for document processing
- **legal-db**: PostgreSQL database for storing analysis results
- **legal-ui**: Web UI dashboard
- **model-runner**: Docker Model Runner for local AI processing

### Directories

- **/incoming-documents**: Place documents here for automatic processing
- **/analysis-results**: Output location for analysis results
- **/config**: Configuration files
- **/ui**: Web dashboard files

## Output

The system generates several output files for each processed document:

1. **Timeline.xlsx**: Excel spreadsheet with events, sentiment analysis, and entities
2. **Analysis_Summary.txt**: Text summary of document analysis
3. **Events.json**: Extracted events in JSON format
4. **Entities.json**: Extracted entities in JSON format
5. **Sentiment.json**: Sentiment analysis results in JSON format

## Performance Optimization

For optimal performance:

1. Use a GPU with CUDA support for faster AI processing
2. Adjust the model quantization level in settings:
   - `int8`: Good balance of speed and quality (default)
   - `int4`: Faster but lower quality
   - `none`: Highest quality but slower

3. Use the Docker Model Runner for local AI processing:
   ```powershell
   cd c:\Projects\autogen
   .\Setup-DockerModelRunner.ps1
   ```

## Troubleshooting

If you encounter issues:

1. Ensure Docker is running and Docker Model Runner is installed
2. Check the console output for error messages
3. Verify file permissions for input and output folders
4. Ensure adequate disk space for document processing
5. For performance issues, consider using a GPU or adjusting model quantization

## Security & Privacy

- All processing happens locally - no data leaves your system
- Document text is stored only temporarily during processing
- Raw documents are not stored unless configured to do so
- No external API calls or internet connectivity required

## Contributing

To contribute improvements:

1. Fork this repository
2. Create a new branch for your feature
3. Add your changes
4. Test thoroughly
5. Submit a pull request

## Legal Disclaimer

This tool provides document analysis for informational purposes only. It does not constitute legal advice and should not be relied upon as such. All processing is performed locally without external API calls.
