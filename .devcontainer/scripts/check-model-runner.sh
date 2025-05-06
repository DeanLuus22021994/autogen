#!/bin/bash
set -e

echo "Checking Docker Model Runner availability..."

# First check network connectivity to Docker host
if ! ping -c 1 -W 2 host.docker.internal > /dev/null 2>&1; then
  echo "❌ Cannot reach host.docker.internal - check Docker network configuration"
  echo "This is required for Docker Model Runner to function properly."
  exit 1
fi

# Check if the Model Runner endpoint is accessible
if curl -s --head --fail --max-time 5 "http://model-runner.docker.internal/engines" > /dev/null; then
  echo "✅ Docker Model Runner is accessible"

  # Get available models
  MODELS=$(curl -s --max-time 5 "http://model-runner.docker.internal/engines")
  if [ $? -eq 0 ] && [ -n "$MODELS" ]; then
    echo "Available models:"
    echo "$MODELS" | jq -r ".[] | .id" 2>/dev/null || echo "$MODELS"
  else
    echo "⚠️ Could not retrieve models list. Docker Model Runner is running but may not have models."
    echo "Run the following to pull a model:"
    echo "  docker model pull ai/mistral"
  fi
else
  echo "❌ Docker Model Runner is not accessible."
  echo "Please ensure:"
  echo "  1. Docker Desktop 4.40+ is running"
  echo "  2. Model Runner is enabled in Docker Desktop settings"
  echo "  3. Network connectivity to Docker host is working"
  echo "  4. No firewall is blocking connections to model-runner.docker.internal"
fi

# Check Docker version
if command -v docker &> /dev/null; then
  DOCKER_VERSION=$(docker version --format "{{.Server.Version}}" 2>/dev/null || docker --version | cut -d" " -f3 | sed "s/,//")
  echo "Docker version: $DOCKER_VERSION"
  if [[ "$DOCKER_VERSION" =~ ^([0-9]+)\.([0-9]+) ]]; then
    MAJOR=${BASH_REMATCH[1]}
    MINOR=${BASH_REMATCH[2]}
    if (( MAJOR < 4 || ( MAJOR == 4 && MINOR < 40 ) )); then
      echo "⚠️ Warning: Docker Model Runner requires Docker Desktop 4.40+"
    fi
  fi
else
  echo "⚠️ Docker CLI not available - cannot check Docker version"
fi