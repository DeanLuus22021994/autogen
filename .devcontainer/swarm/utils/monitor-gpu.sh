#!/bin/bash
# filepath: c:\Projects\autogen\.devcontainer\swarm\utils\monitor-gpu.sh
# GPU monitoring script for Docker Swarm containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

# Default values
INTERVAL=5
FORMAT="csv"
OUTPUT_FILE=""
CONTAINER_NAME=""
SHOW_MEMORY=true
SHOW_UTILIZATION=true
SHOW_POWER=true

# Print usage
function print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Monitor GPU usage in Docker containers"
    echo ""
    echo "Options:"
    echo "  -c, --container NAME      Monitor specific container"
    echo "  -i, --interval SECONDS    Update interval (default: 5)"
    echo "  -f, --format FORMAT       Output format: csv, json, plain (default: csv)"
    echo "  -o, --output FILE         Write to file"
    echo "  --no-memory               Don't show memory usage"
    echo "  --no-utilization          Don't show GPU utilization"
    echo "  --no-power                Don't show power usage"
    echo "  -h, --help                Show this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -c|--container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --no-memory)
            SHOW_MEMORY=false
            shift
            ;;
        --no-utilization)
            SHOW_UTILIZATION=false
            shift
            ;;
        --no-power)
            SHOW_POWER=false
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

# Check if nvidia-smi is available
if ! command -v nvidia-smi &> /dev/null; then
    echo "Error: nvidia-smi is not available. NVIDIA GPU driver might not be installed."
    exit 1
fi

# Build the nvidia-smi query string
QUERY=""
if $SHOW_UTILIZATION; then
    QUERY="${QUERY}utilization.gpu,"
fi
if $SHOW_MEMORY; then
    QUERY="${QUERY}memory.used,memory.total,"
fi
if $SHOW_POWER; then
    QUERY="${QUERY}power.draw,power.limit,"
fi
# Remove trailing comma
QUERY="${QUERY%,}"

# Set up output
if [[ -n "$OUTPUT_FILE" ]]; then
    # Create output file with header
    if [[ "$FORMAT" == "csv" ]]; then
        echo "timestamp,container,gpu_id,${QUERY//,/,}" > "$OUTPUT_FILE"
    elif [[ "$FORMAT" == "json" ]]; then
        echo "[" > "$OUTPUT_FILE"
    fi
fi

# Function to get container GPU metrics
function get_container_gpu_metrics() {
    local container_id="$1"
    local container_name=$(docker inspect --format '{{.Name}}' "$container_id" 2>/dev/null | sed 's/^\///' || echo "$container_id")

    # Get PID namespace for the container
    local pid_namespace=$(docker inspect --format '{{.State.Pid}}' "$container_id" 2>/dev/null)

    if [[ -z "$pid_namespace" || "$pid_namespace" == "0" ]]; then
        echo "Error: Cannot get PID namespace for container $container_name" >&2
        return 1
    fi

    # Get GPU metrics via nvidia-smi
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local gpu_metrics=$(nvidia-smi --query-gpu="index,$QUERY" --format=csv,noheader 2>/dev/null)

    if [[ -z "$gpu_metrics" ]]; then
        echo "Warning: No GPU metrics available for container $container_name" >&2
        return 1
    fi

    # Output metrics
    if [[ "$FORMAT" == "csv" ]]; then
        # CSV format
        echo "$gpu_metrics" | while read -r line; do
            if [[ -n "$OUTPUT_FILE" ]]; then
                echo "$timestamp,$container_name,$line" >> "$OUTPUT_FILE"
            else
                echo "$timestamp,$container_name,$line"
            fi
        done
    elif [[ "$FORMAT" == "json" ]]; then
        # JSON format
        local gpu_index=$(echo "$gpu_metrics" | cut -d ',' -f1)
        local gpu_data=$(echo "$gpu_metrics" | cut -d ',' -f2-)
        local json_output='{'
        json_output+='"timestamp":"'"$timestamp"'",'
        json_output+='"container":"'"$container_name"'",'
        json_output+='"gpu_id":'"$gpu_index"','

        # Parse the rest of the data
        IFS=',' read -ra metrics <<< "$gpu_data"
        local query_parts
        IFS=',' read -ra query_parts <<< "$QUERY"

        for i in "${!query_parts[@]}"; do
            json_output+='"'"${query_parts[$i]}"'":"'"${metrics[$i]}"'"'
            if (( i < ${#query_parts[@]} - 1 )); then
                json_output+=','
            fi
        done

        json_output+='}'

        if [[ -n "$OUTPUT_FILE" ]]; then
            echo "$json_output," >> "$OUTPUT_FILE"
        else
            echo "$json_output"
        fi
    else
        # Plain text
        echo "===== $container_name ====="
        echo "Timestamp: $timestamp"
        echo "GPU Metrics:"
        echo "$gpu_metrics"
        echo "======================="
    fi
}

echo "Starting GPU monitoring (Press Ctrl+C to exit)..."

# Monitor GPU usage in containers
while true; do
    if [[ -n "$CONTAINER_NAME" ]]; then
        # Monitor specific container
        container_id=$(docker ps -q -f "name=$CONTAINER_NAME" 2>/dev/null)
        if [[ -n "$container_id" ]]; then
            get_container_gpu_metrics "$container_id"
        else
            echo "Warning: No container found with name $CONTAINER_NAME" >&2
        fi
    else
        # Monitor all containers using GPUs
        docker ps -q --format '{{.ID}}' 2>/dev/null | while read -r id; do
            get_container_gpu_metrics "$id" || true
        done
    fi

    sleep "$INTERVAL"
done

# Clean up on exit
trap cleanup EXIT
function cleanup() {
    if [[ -n "$OUTPUT_FILE" && "$FORMAT" == "json" ]]; then
        # Remove trailing comma and close JSON array
        sed -i '$ s/,$//' "$OUTPUT_FILE"
        echo "]" >> "$OUTPUT_FILE"
    fi
}
