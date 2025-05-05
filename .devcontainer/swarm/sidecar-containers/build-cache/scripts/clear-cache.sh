#!/bin/bash
# Script to clear the build cache directories

# Define cache directories
CACHE_DIRS=(
  "/cache/dotnet"
  "/cache/dotnet/nuget"
  "/cache/python"
  "/cache/python/pip"
  "/cache/python/uv"
  "/cache/npm"
)

# Parse command line arguments
SPECIFIC_CACHE=""
CONFIRM=false

function show_help {
  echo "Usage: clear-cache.sh [options]"
  echo ""
  echo "Options:"
  echo "  --dotnet    Clear only .NET cache"
  echo "  --python    Clear only Python cache"
  echo "  --npm       Clear only NPM cache"
  echo "  --all       Clear all caches (default)"
  echo "  --yes       Skip confirmation"
  echo "  --help      Show this help message"
  echo ""
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dotnet)
      SPECIFIC_CACHE="dotnet"
      shift
      ;;
    --python)
      SPECIFIC_CACHE="python"
      shift
      ;;
    --npm)
      SPECIFIC_CACHE="npm"
      shift
      ;;
    --all)
      SPECIFIC_CACHE=""
      shift
      ;;
    --yes)
      CONFIRM=true
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

# Function to clear a specific cache directory
clear_cache() {
  local dir=$1
  if [ -d "$dir" ]; then
    echo "Clearing cache: $dir"
    rm -rf "$dir"/*
    mkdir -p "$dir"
    chmod 777 "$dir"
    echo "✅ Cache cleared: $dir"
  else
    echo "⚠️ Cache directory does not exist: $dir"
    mkdir -p "$dir"
    chmod 777 "$dir"
    echo "✅ Cache directory created: $dir"
  fi
}

# Print what will be cleared
if [ -z "$SPECIFIC_CACHE" ]; then
  echo "This will clear ALL build caches:"
  for dir in "${CACHE_DIRS[@]}"; do
    echo "  - $dir"
  done
else
  echo "This will clear the following cache(s):"
  for dir in "${CACHE_DIRS[@]}"; do
    if [[ "$dir" == *"$SPECIFIC_CACHE"* ]]; then
      echo "  - $dir"
    fi
  done
fi

# Confirm unless --yes is passed
if [ "$CONFIRM" != true ]; then
  read -p "Are you sure you want to continue? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
  fi
fi

# Clear the caches
if [ -z "$SPECIFIC_CACHE" ]; then
  # Clear all caches
  for dir in "${CACHE_DIRS[@]}"; do
    clear_cache "$dir"
  done
else
  # Clear specific cache
  for dir in "${CACHE_DIRS[@]}"; do
    if [[ "$dir" == *"$SPECIFIC_CACHE"* ]]; then
      clear_cache "$dir"
    fi
  done
fi

echo "🎉 Cache clearing complete!"
exit 0
