#!/bin/bash
# Script to detect and configure GPU in the container at runtime
# This script avoids installing NVIDIA drivers/toolkit in the container
# and instead uses host-provided drivers via GPU passthrough

# Check if NVIDIA GPU is available through the host
echo "Checking for GPU availability..."

if [ -c /dev/nvidia0 ] || [ -d /proc/driver/nvidia ]; then
    echo "====================================="
    echo "🚀 NVIDIA GPU detected in container!"
    echo "====================================="
    
    # Set environment variables for GPU usage
    export NVIDIA_VISIBLE_DEVICES=all
    export CUDA_VISIBLE_DEVICES=0
    
    # Check for CUDA libraries availability without installing anything
    if [ -f /usr/lib/x86_64-linux-gnu/libcuda.so.1 ] || [ -f /usr/lib/libcuda.so.1 ]; then
        echo "CUDA libraries are accessible from host."
        
        # Get CUDA version information if possible
        if command -v nvidia-smi &> /dev/null; then
            echo "NVIDIA driver information:"
            nvidia-smi --query-gpu=driver_version,name,temperature.gpu,utilization.gpu,utilization.memory --format=csv
        else
            echo "nvidia-smi not found, but GPU is available."
        fi
        
        # Add environment variables to bashrc for persistent setup
        if ! grep -q "NVIDIA_VISIBLE_DEVICES" ~/.bashrc; then
            echo "export NVIDIA_VISIBLE_DEVICES=all" >> ~/.bashrc
            echo "export CUDA_VISIBLE_DEVICES=0" >> ~/.bashrc
        fi
        
        echo "GPU passthrough configured successfully!"
    else
        echo "GPU detected but CUDA libraries not found."
        echo "GPU will be available but may require additional setup for CUDA workloads."
    fi
else
    echo "No NVIDIA GPU detected. Container will run in CPU-only mode."
fi

echo ""
echo "To verify GPU access in Python, you can run:"
echo "python3 -c 'import subprocess; subprocess.run([\"nvidia-smi\"], check=False)'"
echo ""
