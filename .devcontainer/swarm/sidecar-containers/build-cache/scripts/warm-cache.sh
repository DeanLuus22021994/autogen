#!/bin/bash
# Script to warm the build cache with common dependencies

# Define cache directories
CACHE_BASE="/cache"
DOTNET_CACHE="$CACHE_BASE/dotnet"
PYTHON_CACHE="$CACHE_BASE/python"
NPM_CACHE="$CACHE_BASE/npm"

# Parse command line arguments
WARM_DOTNET=false
WARM_PYTHON=false
WARM_NPM=false
VERBOSE=false

function show_help {
  echo "Usage: warm-cache.sh [options]"
  echo ""
  echo "Options:"
  echo "  --dotnet    Warm .NET cache"
  echo "  --python    Warm Python cache"
  echo "  --npm       Warm NPM cache"
  echo "  --all       Warm all caches (default if none specified)"
  echo "  --verbose   Show detailed output"
  echo "  --help      Show this help message"
  echo ""
}

# Parse arguments
if [ $# -eq 0 ]; then
  # If no arguments, warm all caches
  WARM_DOTNET=true
  WARM_PYTHON=true
  WARM_NPM=true
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dotnet)
        WARM_DOTNET=true
        shift
        ;;
      --python)
        WARM_PYTHON=true
        shift
        ;;
      --npm)
        WARM_NPM=true
        shift
        ;;
      --all)
        WARM_DOTNET=true
        WARM_PYTHON=true
        WARM_NPM=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
fi

# Create cache directories if they don't exist
mkdir -p "$DOTNET_CACHE" "$DOTNET_CACHE/nuget" "$PYTHON_CACHE" "$PYTHON_CACHE/pip" "$PYTHON_CACHE/uv" "$NPM_CACHE"
chmod -R 777 "$CACHE_BASE"

# Function to log messages based on verbosity
log() {
  if [ "$VERBOSE" = true ] || [ "$2" = "always" ]; then
    echo "$1"
  fi
}

# Warm the .NET cache
if [ "$WARM_DOTNET" = true ]; then
  log "🔥 Warming .NET cache..." "always"

  # This script doesn't have direct access to dotnet, but we can prepare the directories
  log "Ensuring .NET cache directories are ready" "always"
  mkdir -p "$DOTNET_CACHE/nuget/v3-cache"
  chmod -R 777 "$DOTNET_CACHE"

  log "✅ .NET cache directories prepared" "always"
fi

# Warm the Python cache
if [ "$WARM_PYTHON" = true ]; then
  log "🔥 Warming Python cache..." "always"

  # This script doesn't have direct access to pip/python, but we can prepare the directories
  log "Ensuring Python cache directories are ready" "always"
  mkdir -p "$PYTHON_CACHE/pip/http" "$PYTHON_CACHE/pip/wheels" "$PYTHON_CACHE/uv/cache" "$PYTHON_CACHE/uv/network"
  chmod -R 777 "$PYTHON_CACHE"

  log "✅ Python cache directories prepared" "always"
fi

# Warm the NPM cache
if [ "$WARM_NPM" = true ]; then
  log "🔥 Warming NPM cache..." "always"

  # This script doesn't have direct access to npm, but we can prepare the directories
  log "Ensuring NPM cache directories are ready" "always"
  mkdir -p "$NPM_CACHE/_cacache" "$NPM_CACHE/_locks" "$NPM_CACHE/_logs"
  chmod -R 777 "$NPM_CACHE"

  log "✅ NPM cache directories prepared" "always"
fi

log "🎉 Cache warming complete!" "always"
exit 0
