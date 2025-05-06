#!/bin/bash
# filepath: c:\Projects\autogen\.devcontainer\swarm\utils\optimize-gpu-resources.sh
# GPU resource allocation optimization for Docker Swarm

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

# Default values
MEMORY_FRACTION=0.8
MAX_CONCURRENT_CONTAINERS=1
SWARM_MODE=false
CHECK_ONLY=false
APPLY_DAEMON_CHANGES=false
VERBOSE=false

# Print usage
function print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Optimize GPU resource allocation for Docker containers"
    echo ""
    echo "Options:"
    echo "  -m, --memory-fraction VALUE  GPU memory fraction to allocate (0.1-1.0, default: 0.8)"
    echo "  -c, --max-containers VALUE   Maximum concurrent containers per GPU (default: 1)"
    echo "  -s, --swarm                  Configure for Docker Swarm mode"
    echo "  --check-only                 Check current configuration without making changes"
    echo "  --daemon-config              Apply changes to Docker daemon configuration"
    echo "  -v, --verbose                Enable verbose output"
    echo "  -h, --help                   Show this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -m|--memory-fraction)
            MEMORY_FRACTION="$2"
            shift 2
            ;;
        -c|--max-containers)
            MAX_CONCURRENT_CONTAINERS="$2"
            shift 2
            ;;
        -s|--swarm)
            SWARM_MODE=true
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --daemon-config)
            APPLY_DAEMON_CHANGES=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate memory fraction
if (( $(echo "$MEMORY_FRACTION < 0.1 || $MEMORY_FRACTION > 1.0" | bc -l) )); then
    echo "Error: Memory fraction must be between 0.1 and 1.0"
    exit 1
fi

# Validate max containers
if ! [[ "$MAX_CONCURRENT_CONTAINERS" =~ ^[0-9]+$ ]] || (( MAX_CONCURRENT_CONTAINERS < 1 )); then
    echo "Error: Maximum concurrent containers must be a positive integer"
    exit 1
fi

# Check if nvidia-smi is available
if ! command -v nvidia-smi &> /dev/null; then
    echo "Error: nvidia-smi is not available. NVIDIA GPU driver might not be installed."
    exit 1
fi

# Function to log verbose output
function log_verbose() {
    if $VERBOSE; then
        echo "$@"
    fi
}

# Get GPU information
log_verbose "Checking GPU information..."
GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits 2>/dev/null || echo "0")
if [[ "$GPU_COUNT" == "0" || -z "$GPU_COUNT" ]]; then
    echo "Error: No GPUs detected"
    exit 1
fi

echo "Found $GPU_COUNT GPUs"

# Get GPU memory information
declare -a GPU_MEMORY
for ((i=0; i<GPU_COUNT; i++)); do
    memory=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits -i $i 2>/dev/null || echo "0")
    GPU_MEMORY[$i]=$memory
    log_verbose "GPU $i: ${GPU_MEMORY[$i]} MB total memory"
done

# Calculate optimal memory settings
echo "Calculating optimal GPU resource allocation..."
for ((i=0; i<GPU_COUNT; i++)); do
    allocated_memory=$(echo "${GPU_MEMORY[$i]} * $MEMORY_FRACTION" | bc | cut -d'.' -f1)
    memory_per_container=$(echo "$allocated_memory / $MAX_CONCURRENT_CONTAINERS" | bc | cut -d'.' -f1)

    echo "GPU $i optimization:"
    echo "  - Total memory: ${GPU_MEMORY[$i]} MB"
    echo "  - Allocated memory (${MEMORY_FRACTION}): $allocated_memory MB"
    echo "  - Memory per container: $memory_per_container MB"
    echo "  - Maximum concurrent containers: $MAX_CONCURRENT_CONTAINERS"
done

# Exit if check-only mode is enabled
if $CHECK_ONLY; then
    echo "Check-only mode: No changes applied"
    exit 0
fi

# Configure Docker Swarm
if $SWARM_MODE; then
    echo "Configuring Docker Swarm GPU resources..."

    # Check if Docker is in Swarm mode
    swarm_status=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "inactive")
    if [[ "$swarm_status" != "active" ]]; then
        echo "Docker is not in Swarm mode. Initializing Swarm..."
        docker swarm init || { echo "Failed to initialize Docker Swarm"; exit 1; }
    fi

    # Create a YAML file with the configuration
    cat > "${SCRIPT_DIR}/gpu-resources.yml" <<EOL
version: '3.8'

x-gpu-resource: &gpu-resource
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: 1
            capabilities: [gpu, compute, utility]
  environment:
    - NVIDIA_VISIBLE_DEVICES=all
    - NVIDIA_DRIVER_CAPABILITIES=compute,utility
    - GPU_MEMORY_FRACTION=$MEMORY_FRACTION
EOL

    echo "GPU resource configuration saved to ${SCRIPT_DIR}/gpu-resources.yml"
    echo "Add the following to your Docker Compose service:"
    echo "<<: *gpu-resource"
fi

# Apply Docker daemon configuration changes
if $APPLY_DAEMON_CHANGES; then
    echo "Applying Docker daemon configuration changes..."

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required for daemon configuration but is not installed."
        exit 1
    fi

    # Get daemon.json file path
    if [[ -f "/etc/docker/daemon.json" ]]; then
        DAEMON_FILE="/etc/docker/daemon.json"
    elif [[ -f "$HOME/.docker/daemon.json" ]]; then
        DAEMON_FILE="$HOME/.docker/daemon.json"
    else
        # Create default daemon.json
        mkdir -p "$HOME/.docker"
        DAEMON_FILE="$HOME/.docker/daemon.json"
        echo '{}' > "$DAEMON_FILE"
    fi

    # Backup the original file
    cp "$DAEMON_FILE" "${DAEMON_FILE}.bak"

    # Update the configuration
    jq '.' "$DAEMON_FILE" > /dev/null || { echo "Error: Invalid JSON in $DAEMON_FILE"; exit 1; }

    # Add NVIDIA runtime configuration
    jq '.runtimes.nvidia = {"path": "nvidia-container-runtime", "runtimeArgs": []}' "$DAEMON_FILE" > "${DAEMON_FILE}.tmp"
    mv "${DAEMON_FILE}.tmp" "$DAEMON_FILE"

    # Set default runtime to NVIDIA
    jq '.["default-runtime"] = "nvidia"' "$DAEMON_FILE" > "${DAEMON_FILE}.tmp"
    mv "${DAEMON_FILE}.tmp" "$DAEMON_FILE"

    # Add nvidia-container-runtime configuration
    jq '.["nvidia-container-runtime"] = {"debug": "0", "log-level": "info"}' "$DAEMON_FILE" > "${DAEMON_FILE}.tmp"
    mv "${DAEMON_FILE}.tmp" "$DAEMON_FILE"

    if $SWARM_MODE; then
        # Add node-generic-resources for Swarm
        gpu_resources=""
        for ((i=0; i<GPU_COUNT; i++)); do
            if [[ $i -gt 0 ]]; then
                gpu_resources+=","
            fi
            gpu_resources+="$i"
        done

        jq '.["node-generic-resources"] = ["DOCKER_RESOURCE_GPU='"$gpu_resources"'"]' "$DAEMON_FILE" > "${DAEMON_FILE}.tmp"
        mv "${DAEMON_FILE}.tmp" "$DAEMON_FILE"
    fi

    echo "Docker daemon configuration updated in $DAEMON_FILE"
    echo "Restart Docker to apply changes: systemctl restart docker (Linux) or restart Docker Desktop (Windows/Mac)"
fi

echo "GPU resource optimization complete"
