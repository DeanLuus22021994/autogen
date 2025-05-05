#!/bin/bash
# Example script for using Docker Model Runner with AutoGen

# Check if Docker Model Runner is active
if ! docker model status >/dev/null 2>&1; then
  echo "Docker Model Runner is not active. Please enable it in Docker Desktop settings."
  exit 1
fi

# Pull required models
echo "Pulling models (this may take some time the first time)..."
docker model pull ai/smollm2 || echo "Failed to pull ai/smollm2 - continuing anyway"
docker model pull ai/mistral || echo "Failed to pull ai/mistral - continuing anyway"

# List available models
echo "Available models:"
docker model list

# Example: Run model with direct prompt
echo -e "\nRunning model with direct prompt:"
docker model run ai/smollm2 "Write a short Python function to check if a number is prime"

# Example: Access model via API
echo -e "\nAccessing model via API:"
if command -v curl &> /dev/null; then
  # Check if we can access the API endpoint
  if curl --unix-socket $HOME/.docker/run/docker.sock \
     localhost/exp/vDD4.40/engines/v1/models -s | grep -q "smollm2"; then

    echo "Sending request to model API..."
    curl --unix-socket $HOME/.docker/run/docker.sock \
      localhost/exp/vDD4.40/engines/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{
        "model": "ai/smollm2",
        "messages": [
          {"role": "system", "content": "You are a helpful assistant."},
          {"role": "user", "content": "Write a short Python function to calculate factorial"}
        ]
      }' -s | grep -o '"content":"[^"]*"' | sed 's/"content":"//g' | sed 's/"//g'
  else
    echo "Cannot access API endpoint - Docker Model Runner API may not be available"
  fi
else
  echo "curl command not found - cannot make API requests"
fi

echo -e "\nNote: For AutoGen integration, configure the appropriate endpoint in your configuration."