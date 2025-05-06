# Docker Model Runner Testing Guide

This guide explains how to run tests for the Docker Model Runner integration.

## Prerequisites

- Docker Desktop 4.40+ with Model Runner enabled
- Python 3.8+ with the requests package installed
- At least one model pulled with `docker model pull`

## Running the Unit Tests

To run the unit tests for the Docker Model Runner client:

```bash
cd autogen_extensions/docker
python run_tests.py
```

These tests validate the client's functionality without requiring an actual Docker Model Runner.

## Running the Integration Tests

To verify that Docker Model Runner is properly configured and accessible:

```bash
cd autogen_extensions/docker
python integration_test.py
```

Add the `--verbose` flag for more detailed output:

```bash
python integration_test.py --verbose
```

### What the integration tests check:

1. Docker installation and version
2. Docker Model Runner availability
3. Available models list
4. Model Runner API accessibility (with --verbose)

## Manual Testing

You can also test the Model Runner client manually:

```python
from autogen_extensions.docker.model_client import ModelClient

# Create a client
client = ModelClient(model_name="ai/mistral")

# Check if models are available
models = client.list_available_models()
print(f"Available models: {models}")

# Check if a specific model is available
if client.is_model_available("ai/mistral"):
    # Get a completion
    response = client.complete(
        prompt="Write a function to calculate Fibonacci numbers",
        system_message="You are a helpful coding assistant."
    )
    print(response)
else:
    print("Model not available. Pull it with: docker model pull ai/mistral")
```

## Troubleshooting

If you encounter issues:

1. Make sure Docker Desktop is running
2. Verify Model Runner is enabled in Docker Desktop settings
3. Check that you have pulled at least one model
4. Restart Docker Desktop if necessary
5. Run the integration test with verbose output to diagnose issues
