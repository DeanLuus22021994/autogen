# Docker AI Integration Vocabulary

| Term | Definition | Usage Context |
|------|------------|---------------|
| **Docker Model Runner** | Docker feature for running AI models locally with minimal setup | "Docker Model Runner provides an OpenAI-compatible API endpoint for local model inference" |
| **Gordon** | Docker's AI orchestration tool for complex AI workflows | "Gordon allows you to define AI pipelines with YAML configuration" |
| **MCP** | Model Control Plane, Docker's framework for AI model management | "MCP provides a catalog of pre-trained models and tools for model deployment" |
| **Docker Copilot** | Docker's AI assistant for container development | "Docker Copilot can help optimize Dockerfiles and solve container issues" |
| **AI Model** | Pre-trained machine learning model that can be run via Docker Model Runner | "The mistral AI model can be pulled with `docker model pull ai/mistral`" |
| **Model API** | OpenAI-compatible API provided by Docker Model Runner | "The Model API endpoint is available at `http://model-runner.docker.internal/engines/v1/chat/completions`" |
| **Gordon MCP Server** | Server component of the Gordon Model Control Plane | "The Gordon MCP Server manages model inference requests and scheduling" |
| **MCP Catalog** | Repository of available AI models for Docker | "The MCP Catalog contains models like mistral, smollm2, and other open AI models" |
| **MCP Toolkit** | Set of tools for working with Docker's Model Control Plane | "The MCP Toolkit provides utilities for model conversion and optimization" |
| **YAML Configuration** | YAML-based configuration for Gordon AI workflows | "Gordon YAML configuration defines input sources, models, and output destinations" |