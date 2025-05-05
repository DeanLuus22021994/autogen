#!/bin/bash
# Script to build Python projects with warm startup

# Set default values
PROJECT_PATH=""
BUILD_WHEEL=false
INSTALL=false
EDITABLE=false
CLEAN=false
VERBOSE=false
INSTANT_BUILD=true

function show_help {
  echo "Usage: build-python.sh [options] <project_path>"
  echo ""
  echo "Options:"
  echo "  --wheel                 Build wheel package"
  echo "  --install               Install after building"
  echo "  --editable              Install in editable mode (implies --install)"
  echo "  --clean                 Clean build artifacts before building"
  echo "  --no-instant            Disable instant build optimizations"
  echo "  --verbose               Verbose output"
  echo "  --help                  Show this help message"
  echo ""
  echo "Examples:"
  echo "  build-python.sh /workspace/python/packages/autogen"
  echo "  build-python.sh --wheel --install /workspace/python/packages/autogen"
  echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wheel)
      BUILD_WHEEL=true
      shift
      ;;
    --install)
      INSTALL=true
      shift
      ;;
    --editable)
      INSTALL=true
      EDITABLE=true
      shift
      ;;
    --clean)
      CLEAN=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --no-instant)
      INSTANT_BUILD=false
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
    *)
      PROJECT_PATH="$1"
      shift
      ;;
  esac
done

# Check if project path is provided
if [ -z "$PROJECT_PATH" ]; then
  echo "Error: Project path is required"
  show_help
  exit 1
fi

# Check if project exists
if [ ! -d "$PROJECT_PATH" ]; then
  echo "Error: Project directory not found: $PROJECT_PATH"
  exit 1
fi

# Check if pyproject.toml exists
if [ ! -f "$PROJECT_PATH/pyproject.toml" ]; then
  echo "Warning: pyproject.toml not found in $PROJECT_PATH"
  # Continue anyway, might be using setup.py
fi

# Clean build artifacts if requested
if [ "$CLEAN" = true ]; then
  echo "🧹 Cleaning build artifacts..."

  # Remove common build directories and files
  rm -rf "$PROJECT_PATH/build" "$PROJECT_PATH/dist" "$PROJECT_PATH/*.egg-info"

  # Find and remove __pycache__ directories
  find "$PROJECT_PATH" -type d -name "__pycache__" -exec rm -rf {} +  2>/dev/null || true
  find "$PROJECT_PATH" -name "*.pyc" -delete 2>/dev/null || true

  echo "✅ Clean completed"
fi

# Set environment variables for instant build
if [ "$INSTANT_BUILD" = true ]; then
  echo "🚀 Building with instant build optimizations enabled..."

  # Use uv for faster installs
  USE_UV=true

  # Set environment variables for faster builds
  export PIP_DISABLE_PIP_VERSION_CHECK=1
  export PIP_NO_CACHE_DIR=0
  export PIP_NO_WARN_SCRIPT_LOCATION=0
  export PYTHONDONTWRITEBYTECODE=1
else
  echo "🔨 Building with standard settings..."
  USE_UV=false
fi

# Build wheel if requested
if [ "$BUILD_WHEEL" = true ]; then
  echo "📦 Building wheel package..."

  cd "$PROJECT_PATH"

  if [ "$VERBOSE" = true ]; then
    python3 -m build --wheel --no-isolation
  else
    python3 -m build --wheel --no-isolation > /dev/null
  fi

  BUILD_EXIT_CODE=$?

  if [ $BUILD_EXIT_CODE -ne 0 ]; then
    echo "❌ Wheel build failed with exit code $BUILD_EXIT_CODE"
    exit $BUILD_EXIT_CODE
  fi

  echo "✅ Wheel package built successfully"
fi

# Install if requested
if [ "$INSTALL" = true ]; then
  echo "📥 Installing package..."

  INSTALL_ARGS=""
  if [ "$EDITABLE" = true ]; then
    INSTALL_ARGS="-e"
  fi

  cd "$PROJECT_PATH"

  if [ "$USE_UV" = true ] && command -v uv &> /dev/null; then
    # Use uv for faster installation
    if [ "$VERBOSE" = true ]; then
      uv pip install $INSTALL_ARGS .
    else
      uv pip install $INSTALL_ARGS . > /dev/null
    fi
  else
    # Fall back to regular pip
    if [ "$VERBOSE" = true ]; then
      pip install $INSTALL_ARGS .
    else
      pip install $INSTALL_ARGS . > /dev/null
    fi
  fi

  INSTALL_EXIT_CODE=$?

  if [ $INSTALL_EXIT_CODE -ne 0 ]; then
    echo "❌ Installation failed with exit code $INSTALL_EXIT_CODE"
    exit $INSTALL_EXIT_CODE
  fi

  echo "✅ Package installed successfully"
fi

# If neither wheel nor install was requested, just run a basic verification
if [ "$BUILD_WHEEL" = false ] && [ "$INSTALL" = false ]; then
  echo "🔍 Verifying project..."

  cd "$PROJECT_PATH"

  if [ -f "pyproject.toml" ]; then
    echo "✅ Project verification completed successfully (pyproject.toml found)"
  elif [ -f "setup.py" ]; then
    echo "✅ Project verification completed successfully (setup.py found)"
  else
    echo "⚠️ Warning: Neither pyproject.toml nor setup.py found"
  fi
fi

echo "🎉 Python build process completed!"
exit 0
