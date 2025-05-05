# Pattern: Docker Model Runner Integration

## Purpose
Define a standardized approach for integrating Docker Model Runner with application code to enable local AI model inference.

## When to use
- When you need to run AI models locally without external API dependencies
- When you want to reduce costs associated with cloud-based AI APIs
- When you need offline AI capabilities
- When experimenting with different models in development

## Implementation template

### 1. Docker Model Runner Configuration

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    image: your-application-image
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - MODEL_RUNNER_ENDPOINT=http://model-runner.docker.internal/engines/v1/chat/completions
```
