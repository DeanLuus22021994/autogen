# Setting Up Docker Model Runner Environment

## Prerequisites

- Docker Desktop 4.40+ installed
- Windows, macOS, or Linux with Docker support
- For optimal performance: NVIDIA GPU with appropriate drivers

## Installation Steps

### 1. Install or Update Docker Desktop

Download and install Docker Desktop 4.40 or later from the [official website](https://docs.docker.com/).

### 2. Enable Docker Model Runner

1. Open Docker Desktop
2. Go to Settings
3. Navigate to Features in development > Beta features
4. Enable "Docker Model Runner"
5. Apply changes and restart Docker Desktop

### 3. Verify Installation

Open a terminal and run:

```bash
docker model status
```

You should see output indicating that Docker Model Runner is active.

## Required System Resources

Different models have different resource requirements:

| Model | Minimum RAM | Recommended RAM | Minimum GPU | Disk Space |
|-------|-------------|----------------|-------------|------------|
| ai/mistral | 8GB | 16GB | 4GB VRAM | 8GB |
| ai/smollm2 | 4GB | 8GB | Not required | 2GB |
| ai/mxbai-embed-large | 8GB | 16GB | 4GB VRAM | 4GB |

## Environment Variables

Set these environment variables for integration with Docker Model Runner:

```bash
# For Unix/Linux/macOS
export MODEL_RUNNER_ENDPOINT=http://model-runner.docker.internal/engines/v1/chat/completions

# For Windows Command Prompt
set MODEL_RUNNER_ENDPOINT=http://model-runner.docker.internal/engines/v1/chat/completions

# For Windows PowerShell
$env:MODEL_RUNNER_ENDPOINT="http://model-runner.docker.internal/engines/v1/chat/completions"
```

## Troubleshooting

### Model Runner Not Found

If you get an error like "docker: 'model' is not a docker command", ensure:
- Docker Desktop is running
- You've enabled Model Runner in settings
- Docker Desktop has been restarted after enabling the feature

### Model Download Failures

If model downloads fail:
- Check your internet connection
- Ensure you have enough disk space
- Try with a smaller model first (like ai/smollm2)

### API Connection Issues

If your application can't connect to the Model Runner API:
- Ensure Docker Desktop is running
- Check that the correct endpoint URL is being used
- Verify network settings allow connections to Docker
