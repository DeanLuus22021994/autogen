#!/bin/bash
# Verify Docker Model Runner availability and configuration

set -e

echo "Checking Docker Model Runner configuration..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    exit 1
fi

# Check Docker version
DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
DOCKER_VERSION_MAJOR=$(echo $DOCKER_VERSION | cut -d '.' -f1)
DOCKER_VERSION_MINOR=$(echo $DOCKER_VERSION | cut -d '.' -f2)

echo "🔍 Found Docker version: $DOCKER_VERSION"

# Check if Docker version is 4.40+
if [[ $DOCKER_VERSION_MAJOR -lt 4 ]] || [[ $DOCKER_VERSION_MAJOR -eq 4 && $DOCKER_VERSION_MINOR -lt 40 ]]; then
    echo "❌ Docker version is less than 4.40. Please upgrade Docker Desktop to 4.40+ for Model Runner support."
    exit 1
fi

# Check Docker Model Runner endpoint
ENDPOINT=${MODEL_RUNNER_ENDPOINT:-"http://model-runner.docker.internal/engines/v1/chat/completions"}
ENDPOINT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $ENDPOINT || echo "failed")

if [[ "$ENDPOINT_STATUS" == "failed" ]]; then
    echo "❌ Model Runner endpoint is not accessible"
    echo "Please make sure Docker Desktop is running with Model Runner enabled"
    exit 1
elif [[ "$ENDPOINT_STATUS" == "200" ]] || [[ "$ENDPOINT_STATUS" == "404" ]]; then
    # 404 is acceptable if no request is made to a specific model
    echo "✅ Model Runner endpoint is responsive"
else
    echo "⚠️ Model Runner endpoint returned unexpected status: $ENDPOINT_STATUS"
    exit 1
fi

# Try to check available models
echo "🔍 Checking available models..."
MODELS_ENDPOINT="http://model-runner.docker.internal/engines"
MODELS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $MODELS_ENDPOINT || echo "failed")

if [[ "$MODELS_STATUS" == "failed" ]] || [[ "$MODELS_STATUS" == "404" ]]; then
    echo "⚠️ Cannot list available models, but basic endpoint is working"
    echo "Recommended models to pull: ai/mistral, ai/mistral-nemo, ai/mxbai-embed-large"
else
    MODELS=$(curl -s $MODELS_ENDPOINT)
    echo "✅ Available models: $MODELS"
fi

# All checks passed
echo "✅ Docker Model Runner verification completed successfully"
exit 0
