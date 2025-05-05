#!/bin/bash
# Script to build .NET projects with warm startup

# Set default values
PROJECT_PATH=""
CONFIGURATION="Debug"
FRAMEWORK=""
RUNTIME=""
VERBOSITY="minimal"
PARALLEL=true
INSTANT_BUILD=true

function show_help {
  echo "Usage: build-dotnet.sh [options] <project_path>"
  echo ""
  echo "Options:"
  echo "  --configuration VALUE   Configuration to build (Debug, Release, etc.)"
  echo "  --framework VALUE       Target framework to build for"
  echo "  --runtime VALUE         Target runtime to build for"
  echo "  --no-parallel           Disable parallel build"
  echo "  --no-instant            Disable instant build optimizations"
  echo "  --verbosity VALUE       Set verbosity level (quiet, minimal, normal, detailed, diagnostic)"
  echo "  --help                  Show this help message"
  echo ""
  echo "Examples:"
  echo "  build-dotnet.sh /workspace/AutoGen.sln"
  echo "  build-dotnet.sh --configuration Release --framework net6.0 /workspace/src/MyProject/MyProject.csproj"
  echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --framework)
      FRAMEWORK="$2"
      shift 2
      ;;
    --runtime)
      RUNTIME="$2"
      shift 2
      ;;
    --verbosity)
      VERBOSITY="$2"
      shift 2
      ;;
    --no-parallel)
      PARALLEL=false
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
if [ ! -e "$PROJECT_PATH" ]; then
  echo "Error: Project not found: $PROJECT_PATH"
  exit 1
fi

# Build command arguments
BUILD_ARGS=("build" "$PROJECT_PATH" "--configuration" "$CONFIGURATION")

if [ -n "$FRAMEWORK" ]; then
  BUILD_ARGS+=("--framework" "$FRAMEWORK")
fi

if [ -n "$RUNTIME" ]; then
  BUILD_ARGS+=("--runtime" "$RUNTIME")
fi

if [ "$PARALLEL" = true ]; then
  BUILD_ARGS+=("--maxCpuCount")
fi

BUILD_ARGS+=("--verbosity" "$VERBOSITY")

if [ "$INSTANT_BUILD" = true ]; then
  # Apply MSBuild optimizations for faster builds
  export DOTNET_CLI_TELEMETRY_OPTOUT=1
  export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
  export DOTNET_NOLOGO=1
  export MSBUILDDISABLENODEREUSE=1

  # Enable node reuse for faster builds
  BUILD_ARGS+=("/nr:false")

  # Use in-memory compilation for faster builds
  BUILD_ARGS+=("/p:UseSharedCompilation=true")

  echo "🚀 Building with instant build optimizations enabled..."
else
  echo "🔨 Building with standard settings..."
fi

# Display build command
echo "Running: dotnet ${BUILD_ARGS[*]}"

# Execute build command
dotnet "${BUILD_ARGS[@]}"
BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -eq 0 ]; then
  echo "✅ Build completed successfully!"
else
  echo "❌ Build failed with exit code $BUILD_EXIT_CODE"
fi

exit $BUILD_EXIT_CODE
