# Base image with PowerShell 7
FROM mcr.microsoft.com/powershell:7.3-windowsservercore-ltsc2022

# Set working directory
WORKDIR /app

# Install required software
SHELL ["powershell", "-Command"]

# Install Chocolatey
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install dependencies via Chocolatey
RUN choco install -y xpdf-utils nodejs python3 dotnet-6.0-sdk

# Install required PowerShell modules
RUN Install-Module -Name PSDockConverter -Force -Scope AllUsers; \
    Install-Module -Name ImportExcel -Force -Scope AllUsers

# Copy files
COPY *.ps1 /app/
COPY *.psm1 /app/
COPY legal-analysis-config.xml /app/config/legal-analysis-config.xml

# Create directories
RUN New-Item -ItemType Directory -Path /app/incoming-documents -Force; \
    New-Item -ItemType Directory -Path /app/analysis-results -Force; \
    New-Item -ItemType Directory -Path /app/model-cache -Force; \
    New-Item -ItemType Directory -Path /app/scripts -Force

# Import module
RUN Import-Module -Name "/app/LegalDocumentAnalysis.psm1" -Force

# Set environment variables
ENV MODEL_RUNNER_ENDPOINT=http://model-runner:8000/v1/chat/completions
ENV CONFIG_FILE=/app/config/legal-analysis-config.xml
ENV WATCH_FOLDER=/app/incoming-documents
ENV OUTPUT_FOLDER=/app/analysis-results
ENV MODEL_TYPE=ai/mistral-nemo
ENV QUANTIZATION_LEVEL=int8

# Expose port for API and web interface
EXPOSE 8080

# Start document processing
ENTRYPOINT ["pwsh", "-File", "/app/Process-LegalDocuments.ps1", "-WatchFolder", "/app/incoming-documents", "-OutputFolder", "/app/analysis-results"]
