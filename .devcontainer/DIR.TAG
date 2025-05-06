#INDEX: C:/Projects/autogen/.devcontainer
#GUID: d31607f9-f66f-4e19-8d9b-18aa682fc139
#TODO:
  - Implement container health checks [OUTSTANDING]
  - Configure volume persistence for model cache [PARTIALLY_COMPLETE]
  - Pre-cache VS Code extensions (including Vim) for containerized development [OUTSTANDING]
  - Enable GPU passthrough for containerized model inference [OUTSTANDING]

status: PARTIALLY_COMPLETE
updated: 2025-05-06T08:32:11Z
description: |
  Development container configuration for AutoGen project.
  Supports Docker and Docker Swarm deployment with GPU acceleration.
  Follows containerization best practices: relative paths, extension pre-caching, and modular scripts.

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
