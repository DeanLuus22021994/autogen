#!/bin/bash
# filepath: c:\Projects\autogen\.devcontainer\swarm\utils\check-gpu-support.sh
# Check for GPU support in the container environment

set -e

echo "Checking GPU support in container environment..."

# Check if nvidia-smi is available
if ! command -v nvidia-smi &> /dev/null; then
    echo "ERROR: nvidia-smi command not found. NVIDIA drivers may not be installed or accessible."
    echo "GPU support is NOT available in this container."
    exit 1
fi

# Check if we can get GPU information
echo "Querying GPU information..."
GPU_INFO=$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null || echo "ERROR")

if [[ "$GPU_INFO" == "ERROR" ]]; then
    echo "ERROR: Failed to query GPU information with nvidia-smi."
    echo "GPU support is NOT properly configured in this container."
    exit 1
fi

# Show GPU information
echo "GPU support is AVAILABLE in this container:"
echo "$GPU_INFO" | while IFS="," read -r NAME VERSION MEMORY; do
    echo "- GPU: $NAME"
    echo "  Driver Version: $VERSION"
    echo "  Total Memory: $MEMORY"
done

# Check Docker runtime
if command -v docker &> /dev/null; then
    echo "Checking Docker GPU runtime configuration..."
    DOCKER_INFO=$(docker info --format '{{json .}}' 2>/dev/null || echo '{"error": true}')

    # Check for Nvidia runtime
    if echo "$DOCKER_INFO" | grep -q "nvidia"; then
        echo "NVIDIA runtime is configured in Docker."

        # Check default runtime
        DEFAULT_RUNTIME=$(echo "$DOCKER_INFO" | grep -o '"DefaultRuntime":"[^"]*"' | cut -d'"' -f4)
        if [[ "$DEFAULT_RUNTIME" == "nvidia" ]]; then
            echo "NVIDIA is set as the default runtime."
        else
            echo "WARNING: NVIDIA is NOT set as the default runtime (current: $DEFAULT_RUNTIME)."
            echo "For optimal GPU performance, consider setting NVIDIA as the default runtime."
        fi
    else
        echo "WARNING: NVIDIA runtime is NOT configured in Docker."
        echo "For GPU support, configure the NVIDIA runtime in your Docker daemon.json."
    fi
fi

# Check CUDA availability
if command -v nvcc &> /dev/null; then
    echo "Checking CUDA toolkit version..."
    CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | cut -c2-)
    echo "CUDA Toolkit Version: $CUDA_VERSION"
else
    echo "NOTE: CUDA toolkit is not installed in this container."
    echo "This is normal if you're only using GPU for inference with pre-built libraries."
fi

# Check for common ML/AI libraries with GPU support
echo "Checking for common GPU-accelerated libraries..."

# Check TensorFlow
if python -c "import tensorflow as tf; print(f'TensorFlow {tf.__version__} with GPU support: {len(tf.config.list_physical_devices(\"GPU\")) > 0}')" 2>/dev/null; then
    echo "✓ TensorFlow is installed with GPU support."
elif python -c "import tensorflow as tf; print(f'TensorFlow {tf.__version__} without GPU support')" 2>/dev/null; then
    echo "⚠ TensorFlow is installed but WITHOUT GPU support."
fi

# Check PyTorch
if python -c "import torch; print(f'PyTorch {torch.__version__} with GPU support: {torch.cuda.is_available()}')" 2>/dev/null; then
    echo "✓ PyTorch is installed with GPU support."
elif python -c "import torch; print(f'PyTorch {torch.__version__} without GPU support')" 2>/dev/null; then
    echo "⚠ PyTorch is installed but WITHOUT GPU support."
fi

# Check GPU allocation
echo "Checking GPU memory allocation..."
nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total --format=csv

echo "GPU check completed successfully."
exit 0
