# Script to fix GitHub workflow files
# This script identifies and fixes formatting issues in GitHub workflow files

# Set to stop on errors
$ErrorActionPreference = "Stop"

Write-Host "Starting GitHub workflow file fixes..." -ForegroundColor Cyan

# Function to fix the refresh-sidecar-containers.yml file
function Fix-RefreshSidecarContainersFile {
    $filePath = "$PSScriptRoot\..\..\\.github\workflows\refresh-sidecar-containers.yml"
    $backupPath = "$PSScriptRoot\..\..\\.github\workflows\refresh-sidecar-containers.yml.bak"

    # Create a backup if it doesn't exist
    if (-not (Test-Path $backupPath)) {
        Copy-Item -Path $filePath -Destination $backupPath
        Write-Host "Created backup at $backupPath" -ForegroundColor Green
    }

    # Create fixed content
    $fixedContent = @"
name: Refresh Sidecar Containers

on:
  # Run weekly on Monday at 3 AM UTC
  schedule:
    - cron: '0 3 * * 1'

  # Allow manual triggering
  workflow_dispatch:
    inputs:
      force_rebuild:
        description: 'Force rebuild all containers'
        required: false
        default: false
        type: boolean

jobs:
  build-containers:
    name: Build and Push Sidecar Containers
    runs-on: ubuntu-latest
    strategy:
      matrix:
        container: ['markdown-lint', 'build-cache', 'build-tools']
      fail-fast: false

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Get current date
        id: date
        run: echo "date=`$(date +'%Y%m%d')" >> `$GITHUB_OUTPUT

      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: |
            ghcr.io/microsoft/autogen-`${{ matrix.container }}
          tags: |
            type=raw,value=latest
            type=raw,value=`${{ steps.date.outputs.date }}
            type=sha,format=short

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: `${{ github.actor }}
          password: `${{ secrets.GITHUB_TOKEN }}

      - name: Build and push image
        id: build
        uses: docker/build-push-action@v4
        with:
          context: ./.devcontainer/swarm/sidecar-containers/`${{ matrix.container }}
          push: true
          tags: `${{ steps.meta.outputs.tags }}
          labels: `${{ steps.meta.outputs.labels }}
          cache-from: type=registry,ref=ghcr.io/microsoft/autogen-`${{ matrix.container }}:latest
          cache-to: type=inline
          build-args: |
            BUILDTIME=`${{ fromJSON('["", "--no-cache"]')[github.event.inputs.force_rebuild == 'true'] }}

      - name: Image digest
        run: echo `${{ steps.build.outputs.digest }}

  update-compose:
    name: Update Docker Compose Configuration
    needs: build-containers
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Get current date
        id: date
        run: echo "date=`$(date +'%Y%m%d')" >> `$GITHUB_OUTPUT

      - name: Update Docker Compose file
        run: |
          COMPOSE_FILE=.devcontainer/swarm/sidecar-containers/docker-compose.yml
          DATE_TAG=`${{ steps.date.outputs.date }}

          # Update docker-compose.yml to use the published images instead of build directives
          sed -i 's/build:/image: ghcr.io\/microsoft\/autogen-markdown-lint:'\$DATE_TAG'\n    #build:/' `$COMPOSE_FILE
          sed -i 's/context: .\/markdown-lint/#context: .\/markdown-lint/' `$COMPOSE_FILE
          sed -i 's/dockerfile: Dockerfile/#dockerfile: Dockerfile/' `$COMPOSE_FILE

          sed -i 's/build:/image: ghcr.io\/microsoft\/autogen-build-cache:'\$DATE_TAG'\n    #build:/' `$COMPOSE_FILE | grep -v "image: ghcr.io/microsoft/autogen-markdown-lint"
          sed -i 's/context: .\/build-cache/#context: .\/build-cache/' `$COMPOSE_FILE
          sed -i 's/dockerfile: Dockerfile/#dockerfile: Dockerfile/' `$COMPOSE_FILE

          sed -i 's/build:/image: ghcr.io\/microsoft\/autogen-build-tools:'\$DATE_TAG'\n    #build:/' `$COMPOSE_FILE | grep -v "image: ghcr.io/microsoft/autogen-build-cache" | grep -v "image: ghcr.io/microsoft/autogen-markdown-lint"
          sed -i 's/context: .\/build-tools/#context: .\/build-tools/' `$COMPOSE_FILE
          sed -i 's/dockerfile: Dockerfile/#dockerfile: Dockerfile/' `$COMPOSE_FILE

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v5
        with:
          token: `${{ secrets.GITHUB_TOKEN }}
          branch: update-sidecar-containers-`${{ steps.date.outputs.date }}
          title: 'Update sidecar container images to `${{ steps.date.outputs.date }}'
          commit-message: 'chore: update sidecar container images to `${{ steps.date.outputs.date }}'
          body: |
            This PR updates the Docker Compose configuration to use the latest sidecar container images.

            - Updates markdown-lint container to tag `${{ steps.date.outputs.date }}
            - Updates build-cache container to tag `${{ steps.date.outputs.date }}
            - Updates build-tools container to tag `${{ steps.date.outputs.date }}

            This change allows developers to use pre-built container images instead of building them locally.
          labels: |
            automated-pr
            dependencies
          reviewers: `${{ github.actor }}
"@

    # Write the fixed content to the file
    $fixedContent | Out-File -FilePath $filePath -Encoding utf8
    Write-Host "Fixed $filePath" -ForegroundColor Green
}

# Fix the README.md file for Docker Model Runner
function Fix-DockerReadmeFile {
    $filePath = "c:\Projects\autogen\autogen_extensions\docker\README.md"

    # Read the content of the file
    $content = Get-Content -Path $filePath -Raw

    # Fix the heading with trailing punctuation
    $fixedContent = $content -replace "### What the integration tests check:", "### What the integration tests check"

    # Write the fixed content
    $fixedContent | Out-File -FilePath $filePath -Encoding utf8
    Write-Host "Fixed Docker README.md file" -ForegroundColor Green
}

# Create an XML configuration file for Docker documentation
function Create-DockerDocumentationXML {
    $filePath = "c:\Projects\autogen\.config\host\docker_documentation.xml"

    # Create the directory if it doesn't exist
    $directory = [System.IO.Path]::GetDirectoryName($filePath)
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Write-Host "Created directory $directory" -ForegroundColor Green
    }

    # Create the XML content
    $xmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<docker_documentation>
  <model_runner>
    <enabled>true</enabled>
    <version>beta</version>
    <min_docker_version>4.40.0</min_docker_version>
    <endpoint>http://model-runner.docker.internal/engines/v1/chat/completions</endpoint>
  </model_runner>
  <models>
    <model>
      <name>ai/mistral</name>
      <description>Mistral AI's base model</description>
      <capabilities>
        <capability>text-generation</capability>
        <capability>chat</capability>
      </capabilities>
    </model>
    <model>
      <name>ai/mistral-nemo</name>
      <description>Mistral AI's model optimized with NVIDIA NeMo</description>
      <capabilities>
        <capability>text-generation</capability>
        <capability>chat</capability>
      </capabilities>
    </model>
    <model>
      <name>ai/mxbai-embed-large</name>
      <description>Text embedding model</description>
      <capabilities>
        <capability>embeddings</capability>
      </capabilities>
    </model>
    <model>
      <name>ai/smollm2</name>
      <description>Small, lightweight model for resource-constrained environments</description>
      <capabilities>
        <capability>text-generation</capability>
        <capability>chat</capability>
      </capabilities>
    </model>
  </models>
  <api_references>
    <reference>
      <name>Docker Model Runner API</name>
      <url>https://docs.docker.com/engine/api/model-runner/</url>
    </reference>
    <reference>
      <name>OpenAI API Compatibility</name>
      <url>https://platform.openai.com/docs/api-reference</url>
    </reference>
  </api_references>
</docker_documentation>
"@

    # Write the XML to the file
    $xmlContent | Out-File -FilePath $filePath -Encoding utf8
    Write-Host "Created Docker documentation XML at $filePath" -ForegroundColor Green
}

# Create XML schema for Docker documentation
function Create-DockerDocumentationSchema {
    $filePath = "c:\Projects\autogen\.github\schemas\docker_documentation_schema.xsd"

    # Create the directory if it doesn't exist
    $directory = [System.IO.Path]::GetDirectoryName($filePath)
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Write-Host "Created directory $directory" -ForegroundColor Green
    }

    # Create the XSD content
    $xsdContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="docker_documentation">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="model_runner">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="enabled" type="xs:boolean"/>
              <xs:element name="version" type="xs:string"/>
              <xs:element name="min_docker_version" type="xs:string"/>
              <xs:element name="endpoint" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
        <xs:element name="models">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="model" maxOccurs="unbounded">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element name="name" type="xs:string"/>
                    <xs:element name="description" type="xs:string"/>
                    <xs:element name="capabilities">
                      <xs:complexType>
                        <xs:sequence>
                          <xs:element name="capability" type="xs:string" maxOccurs="unbounded"/>
                        </xs:sequence>
                      </xs:complexType>
                    </xs:element>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
        <xs:element name="api_references">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="reference" maxOccurs="unbounded">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element name="name" type="xs:string"/>
                    <xs:element name="url" type="xs:string"/>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>
"@

    # Write the XSD to the file
    $xsdContent | Out-File -FilePath $filePath -Encoding utf8
    Write-Host "Created Docker documentation schema at $filePath" -ForegroundColor Green
}

# Run the functions
try {
    Fix-RefreshSidecarContainersFile
    Fix-DockerReadmeFile
    Create-DockerDocumentationXML
    Create-DockerDocumentationSchema

    Write-Host "All fixes applied successfully!" -ForegroundColor Green
    Write-Host "Please run 'git status' to see the changes that have been made" -ForegroundColor Yellow
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
