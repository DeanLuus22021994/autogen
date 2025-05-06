# Enhanced DevContainer for AutoGen with Docker Model Runner Integration

This document outlines the setup for a permanent DevContainer with Docker Model Runner integration, leveraging volumes for fast code access and development.

## Features

- Persistent container with precompiled dev team code stored in volumes
- Docker Model Runner integration with local AI models
- Low-footprint container (GPU passthrough, no toolkit installation)
- DIR.TAG tracking system integration
- Optimized for agile sprint development

## Prerequisites

- Docker Desktop 4.40+
- Docker Model Runner enabled in Docker Desktop settings
- VS Code with Dev Containers extension installed
- Git with credentials configured

## Setup Instructions

1. Enable Docker Model Runner in Docker Desktop settings
2. Clone the repository and open in VS Code
3. Run the DevContainer setup script
4. Verify the Docker Model Runner integration

## Components

### 1. DevContainer Configuration
- Enhanced Dockerfile with optimization settings
- Docker Compose with persistent volumes
- Integration with Docker Model Runner

### 2. Volume Configuration
- Dedicated volumes for:
  - Python packages (precompiled)
  - .NET build artifacts (precompiled)
  - Docker Model Runner models

### 3. DIR.TAG Integration
- Automated tracking of directory status
- XML configuration for automation tools

### 4. Scripts
- Container initialization
- Volume management
- Model Runner setup

## Docker Model Runner Integration

The following Docker images are available via Docker Model Runner:
- ai/mistral
- ai/mistral-nemo
- ai/mxbai-embed-large
- ai/smollm2

## Usage Notes

- Use the precompiled code for faster development cycles
- Docker Model Runner is accessible via the client in `autogen_extensions/docker`
- DIR.TAG files track the status of directories and development tasks
