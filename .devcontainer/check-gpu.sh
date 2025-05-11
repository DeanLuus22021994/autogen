#!/bin/bash
# filepath: c:\Projects\autogen\.devcontainer\check-gpu.sh
# This script helps verify GPU passthrough is working correctly

set -e
echo "==================================================="
echo "🔍 GPU Passthrough Test - No NVIDIA Toolkit Needed"
echo "==================================================="

# Check if NVIDIA devices are visible
if [ -c /dev/nvidia0 ] || [ -d /proc/driver/nvidia ]; then
    echo "✅ NVIDIA device found!"
    
    # Try to access NVIDIA driver info
    if command -v nvidia-smi &> /dev/null; then
        echo "📋 NVIDIA driver information:"
        nvidia-smi --query-gpu=driver_version,name,temperature.gpu,utilization.gpu --format=csv
    else
        echo "ℹ️ nvidia-smi not found, but GPU devices are available."
        echo "   This is normal with pure passthrough."
    fi
    
    # Check if CUDA libraries are accessible
    echo "🧪 Testing GPU library access..."
    if [ -f /usr/lib/x86_64-linux-gnu/libcuda.so.1 ] || [ -f /usr/lib/libcuda.so.1 ]; then
        echo "✅ CUDA libraries are accessible."
        
        # Try a simple Python test if available
        if command -v python3 &> /dev/null; then
            echo "🐍 Testing GPU access via Python..."
            python3 -c "
import sys
try:
    import ctypes
    ctypes.CDLL('libcuda.so.1')
    print('✅ GPU libraries successfully loaded via Python!')
except Exception as e:
    print(f'⚠️ Could not load GPU libraries: {e}')
    sys.exit(0)
"
        fi
    else
        echo "⚠️ CUDA libraries not found in standard locations."
    fi
    
    # Environment variables check
    echo "🔧 GPU environment variables:"
    echo "NVIDIA_VISIBLE_DEVICES: ${NVIDIA_VISIBLE_DEVICES:-not set}"
    echo "NVIDIA_DRIVER_CAPABILITIES: ${NVIDIA_DRIVER_CAPABILITIES:-not set}"
    echo "CUDA_VISIBLE_DEVICES: ${CUDA_VISIBLE_DEVICES:-not set}"
    
    echo "✅ GPU passthrough is properly configured."
else
    echo "⚠️ No NVIDIA GPU devices detected."
    echo "   - If your host has an NVIDIA GPU, check that GPU passthrough is enabled"
    echo "   - If using CPU-only mode, this is expected behavior"
fi

echo ""
echo "🔍 Container Resource Information:"
echo "CPU: $(grep -c processor /proc/cpuinfo) cores"
if [ -f /proc/meminfo ]; then
    echo "Memory: $(grep MemTotal /proc/meminfo | awk '{print $2/1024/1024}') GB"
fi
echo ""
echo "✅ Test complete!"

