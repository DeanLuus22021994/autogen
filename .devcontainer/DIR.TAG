#INDEX: C:/Projects/autogen/.devcontainer
#GUID: 0e9c49cb-6c30-49e3-99df-42a073913a3b
#TODO:
  - Configure Docker Model Runner integration with VS Code DONE
  - Set up persistent volumes for code development DONE
  - Implement startup script for environment configuration DONE
  - Create documentation for enhanced container setup DONE
  - Optimize container for long-running permanent operation DONE
  - Implement precompiled code handling in volumes DONE
  - Add comprehensive network connectivity checks DONE
  - Support cross-shell environments (Bash and PowerShell) DONE
  - Configure NVIDIA GPU passthrough for Docker containers DONE
  - Optimize Docker Swarm settings for high-performance operation DONE
  - Implement GPU resource allocation for AI model inference DONE
  - Set up container health checks for GPU availability PARTIALLY_COMPLETE

status: DONE
updated: 2025-05-06T06:38:54Z
description: |
  Enhanced DevContainer configuration with Docker Model Runner integration,
  persistent volumes for fast development, and optimized setup for agile
  sprint development cycles. The container is configured for permanent
  operation with precompiled code stored in volumes for optimal performance.

  Docker Model Runner Integration:
  - Integration with Docker Desktop 4.40+ for local AI models
  - Support for models: ai/mistral, ai/mistral-nemo, ai/mxbai-embed-large, ai/smollm2
  - Container networking configured for Model Runner access
  - Persistent volume for model storage to avoid redownloading

  NVIDIA GPU Acceleration:
  - GPU passthrough configuration for Docker containers
  - Optimized resource allocation for AI workloads
  - Docker Swarm mode support with GPU resources
