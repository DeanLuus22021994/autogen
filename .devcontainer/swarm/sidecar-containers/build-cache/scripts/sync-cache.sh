#!/bin/bash
# Script to synchronize build cache with an external directory

# Define cache directories
CACHE_BASE="/cache"
DOTNET_CACHE="$CACHE_BASE/dotnet"
PYTHON_CACHE="$CACHE_BASE/python"
NPM_CACHE="$CACHE_BASE/npm"

# Parse command line arguments
SOURCE_DIR=""
TARGET_DIR=""
SYNC_DOTNET=false
SYNC_PYTHON=false
SYNC_NPM=false
VERBOSE=false
DRY_RUN=false
DIRECTION="to-cache" # can be "to-cache" or "from-cache"

function show_help {
  echo "Usage: sync-cache.sh [options]"
  echo ""
  echo "Options:"
  echo "  --source DIR      Source directory to sync from"
  echo "  --target DIR      Target directory to sync to (if not using default cache locations)"
  echo "  --dotnet          Sync .NET cache"
  echo "  --python          Sync Python cache"
  echo "  --npm             Sync NPM cache"
  echo "  --all             Sync all caches (default if no specific cache is selected)"
  echo "  --from-cache      Sync from cache to external directory (default is to-cache)"
  echo "  --to-cache        Sync from external directory to cache"
  echo "  --verbose         Show detailed output"
  echo "  --dry-run         Show what would be synced without actually syncing"
  echo "  --help            Show this help message"
  echo ""
  echo "Examples:"
  echo "  sync-cache.sh --source /external/cache --all --to-cache"
  echo "  sync-cache.sh --source /project --python --from-cache"
  echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE_DIR="$2"
      shift 2
      ;;
    --target)
      TARGET_DIR="$2"
      shift 2
      ;;
    --dotnet)
      SYNC_DOTNET=true
      shift
      ;;
    --python)
      SYNC_PYTHON=true
      shift
      ;;
    --npm)
      SYNC_NPM=true
      shift
      ;;
    --all)
      SYNC_DOTNET=true
      SYNC_PYTHON=true
      SYNC_NPM=true
      shift
      ;;
    --from-cache)
      DIRECTION="from-cache"
      shift
      ;;
    --to-cache)
      DIRECTION="to-cache"
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
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

# If no specific cache is selected, sync all
if [ "$SYNC_DOTNET" = false ] && [ "$SYNC_PYTHON" = false ] && [ "$SYNC_NPM" = false ]; then
  SYNC_DOTNET=true
  SYNC_PYTHON=true
  SYNC_NPM=true
fi

# Check required arguments
if [ -z "$SOURCE_DIR" ]; then
  echo "Error: Source directory (--source) is required"
  show_help
  exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory does not exist: $SOURCE_DIR"
  exit 1
fi

# Function to log messages based on verbosity
log() {
  if [ "$VERBOSE" = true ] || [ "$2" = "always" ]; then
    echo "$1"
  fi
}

# Function to sync a specific cache
sync_cache() {
  local src=$1
  local dst=$2
  local cache_type=$3

  # Create destination directory if it doesn't exist
  if [ ! -d "$dst" ]; then
    log "Creating directory: $dst"
    mkdir -p "$dst"
  fi

  # Construct rsync command
  local rsync_cmd="rsync -a"

  if [ "$VERBOSE" = true ]; then
    rsync_cmd="$rsync_cmd --verbose"
  fi

  if [ "$DRY_RUN" = true ]; then
    rsync_cmd="$rsync_cmd --dry-run"
  fi

  # Add trailing slash to source to copy contents, not the directory itself
  src="${src%/}/"

  log "Syncing $cache_type cache: $src -> $dst" "always"

  # Execute rsync
  eval "$rsync_cmd \"$src\" \"$dst\""
  local status=$?

  if [ $status -eq 0 ]; then
    log "✅ Successfully synced $cache_type cache" "always"
  else
    log "❌ Failed to sync $cache_type cache (status: $status)" "always"
  fi

  return $status
}

# Sync each selected cache
exit_status=0

if [ "$SYNC_DOTNET" = true ]; then
  if [ "$DIRECTION" = "to-cache" ]; then
    src="$SOURCE_DIR/dotnet"
    dst="$DOTNET_CACHE"
  else
    src="$DOTNET_CACHE"
    dst="${TARGET_DIR:-$SOURCE_DIR}/dotnet"
  fi

  if [ -d "$src" ]; then
    sync_cache "$src" "$dst" ".NET"
    [ $? -ne 0 ] && exit_status=1
  else
    log "⚠️ Source directory for .NET cache does not exist: $src" "always"
  fi
fi

if [ "$SYNC_PYTHON" = true ]; then
  if [ "$DIRECTION" = "to-cache" ]; then
    src="$SOURCE_DIR/python"
    dst="$PYTHON_CACHE"
  else
    src="$PYTHON_CACHE"
    dst="${TARGET_DIR:-$SOURCE_DIR}/python"
  fi

  if [ -d "$src" ]; then
    sync_cache "$src" "$dst" "Python"
    [ $? -ne 0 ] && exit_status=1
  else
    log "⚠️ Source directory for Python cache does not exist: $src" "always"
  fi
fi

if [ "$SYNC_NPM" = true ]; then
  if [ "$DIRECTION" = "to-cache" ]; then
    src="$SOURCE_DIR/npm"
    dst="$NPM_CACHE"
  else
    src="$NPM_CACHE"
    dst="${TARGET_DIR:-$SOURCE_DIR}/npm"
  fi

  if [ -d "$src" ]; then
    sync_cache "$src" "$dst" "NPM"
    [ $? -ne 0 ] && exit_status=1
  else
    log "⚠️ Source directory for NPM cache does not exist: $src" "always"
  fi
fi

if [ $exit_status -eq 0 ]; then
  log "🎉 Cache synchronization complete!" "always"
else
  log "⚠️ Cache synchronization completed with errors." "always"
fi

exit $exit_status
