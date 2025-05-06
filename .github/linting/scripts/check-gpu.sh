#!/bin/bash
# GPU availability check for Docker container

set -e

echo "Checking GPU availability..."

# Check if nvidia-smi is available
if command -v nvidia-smi &> /dev/null; then
    # Display GPU information
    echo "GPU Information:"
    nvidia-smi

    # Check for RTX 3060 specifically
    if nvidia-smi -L | grep -q "RTX 3060"; then
        echo "✅ NVIDIA RTX 3060 detected and ready for use"
    else
        echo "⚠️ NVIDIA GPU detected, but not an RTX 3060. Test performance may vary."
    fi

    # Check for CUDA availability
    if [ -d "/usr/local/cuda" ]; then
        echo "✅ CUDA installation found at /usr/local/cuda"
    else
        echo "⚠️ CUDA installation not found at expected location"
    fi
else
    echo "⚠️ Warning: nvidia-smi not found, GPU acceleration will not be available"
    echo "Running in CPU-only mode"
fi

# Execute the command passed to the container
exec "$@"