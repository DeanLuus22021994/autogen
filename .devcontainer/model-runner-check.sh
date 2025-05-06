#!/bin/bash
# filepath: c:\Projects\autogen\.devcontainer\model-runner-check.sh
# Comprehensive Docker Model Runner validation script
# For AutoGen enhanced DevContainer

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Docker Model Runner Comprehensive Check ===${NC}"
echo

# Function to check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Check if we're in a container
check_container() {
  if [ -f "/.dockerenv" ]; then
    echo -e "${GREEN}Running inside container: YES${NC}"
  else
    echo -e "${YELLOW}Running inside container: NO${NC}"
    echo -e "${YELLOW}This script is designed to run inside the DevContainer${NC}"
  fi
}

# Check Docker CLI
check_docker_cli() {
  echo -e "\n${BLUE}=== Docker CLI Check ===${NC}"
  if command_exists docker; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}Docker CLI available: $DOCKER_VERSION${NC}"

    # Check Docker version specifically to ensure it's 4.40+
    VERSION_NUM=$(echo $DOCKER_VERSION | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ "$VERSION_NUM" =~ ^([0-9]+)\.([0-9]+) ]]; then
      MAJOR=${BASH_REMATCH[1]}
      MINOR=${BASH_REMATCH[2]}
      if (( MAJOR < 4 || ( MAJOR == 4 && MINOR < 40 ) )); then
        echo -e "${YELLOW}⚠️ Warning: Docker Model Runner requires Docker Desktop 4.40+${NC}"
        echo -e "${YELLOW}Current version: $VERSION_NUM${NC}"
      else
        echo -e "${GREEN}✅ Docker version meets requirements for Model Runner${NC}"
      fi
    fi
  else
    echo -e "${RED}❌ Docker CLI not available${NC}"
    echo -e "${YELLOW}Check that Docker is properly installed and in PATH${NC}"
    return 1
  fi

  # Try docker model command
  if docker model --help &>/dev/null; then
    echo -e "${GREEN}✅ Docker Model CLI extension available${NC}"
  else
    echo -e "${RED}❌ Docker Model CLI extension not available${NC}"
    echo -e "${YELLOW}This is required for Docker Model Runner to work${NC}"
    return 1
  fi

  return 0
}

# Check network connectivity
check_network() {
  echo -e "\n${BLUE}=== Network Connectivity Check ===${NC}"

  echo "Testing connectivity to host.docker.internal..."
  if ping -c 1 -W 2 host.docker.internal &>/dev/null; then
    echo -e "${GREEN}✅ Can reach host.docker.internal${NC}"
  else
    echo -e "${RED}❌ Cannot reach host.docker.internal${NC}"
    echo -e "${YELLOW}This is required for Docker Model Runner to function${NC}"
    return 1
  fi

  echo "Testing connectivity to model-runner.docker.internal..."
  if ping -c 1 -W 2 model-runner.docker.internal &>/dev/null; then
    echo -e "${GREEN}✅ Can reach model-runner.docker.internal${NC}"
  else
    echo -e "${RED}❌ Cannot reach model-runner.docker.internal${NC}"
    echo -e "${YELLOW}Check your /etc/hosts or Docker network configuration${NC}"
    return 1
  fi

  return 0
}

# Check Model Runner API
check_model_runner() {
  echo -e "\n${BLUE}=== Model Runner API Check ===${NC}"

  echo "Testing connectivity to Model Runner API..."
  if curl -s --head --fail --max-time 5 "http://model-runner.docker.internal/engines" &>/dev/null; then
    echo -e "${GREEN}✅ Model Runner API is accessible${NC}"

    # Get models list
    MODELS_JSON=$(curl -s --max-time 5 "http://model-runner.docker.internal/engines")
    if [ $? -eq 0 ] && [ -n "$MODELS_JSON" ]; then
      echo -e "${GREEN}Available models:${NC}"
      echo "$MODELS_JSON" | jq -r ".[] | .id" 2>/dev/null || echo "$MODELS_JSON"
    else
      echo -e "${YELLOW}⚠️ Could not retrieve models list${NC}"
      echo -e "${YELLOW}Model Runner API is running but may not have models loaded${NC}"
    fi
  else
    echo -e "${RED}❌ Model Runner API is not accessible${NC}"
    echo -e "${YELLOW}Ensure Docker Desktop is running with Model Runner enabled:${NC}"
    echo "1. Open Docker Desktop"
    echo "2. Go to Settings > Beta Features"
    echo "3. Enable Docker Model Runner"
    echo "4. Restart Docker Desktop"
    return 1
  fi

  return 0
}

# Check volume persistence
check_volumes() {
  echo -e "\n${BLUE}=== Volume Persistence Check ===${NC}"

  # Check Python virtual environment
  if [ -d "/workspaces/autogen/python/.venv" ]; then
    echo -e "${GREEN}✅ Python virtual environment volume exists${NC}"
    # Check if any packages are installed
    if [ -d "/workspaces/autogen/python/.venv/lib/python3.10/site-packages" ]; then
      PACKAGE_COUNT=$(ls /workspaces/autogen/python/.venv/lib/python3.10/site-packages | wc -l)
      echo -e "${GREEN}   $PACKAGE_COUNT packages installed${NC}"
    else
      echo -e "${YELLOW}⚠️ Python virtual environment exists but may be empty${NC}"
    fi
  else
    echo -e "${YELLOW}⚠️ Python virtual environment volume not found${NC}"
    echo -e "${YELLOW}   Will be created on first container startup${NC}"
  fi

  # Check .NET artifacts
  if [ -d "/workspaces/autogen/dotnet/artifacts" ]; then
    echo -e "${GREEN}✅ .NET artifacts volume exists${NC}"
  else
    echo -e "${YELLOW}⚠️ .NET artifacts volume not found${NC}"
    echo -e "${YELLOW}   Will be created on first container startup${NC}"
  fi

  # Check model cache
  if [ -d "/opt/autogen/models" ]; then
    echo -e "${GREEN}✅ Model cache volume exists${NC}"
    # Check if any models are cached
    MODEL_COUNT=$(find /opt/autogen/models -type f 2>/dev/null | wc -l)
    if [ $MODEL_COUNT -gt 0 ]; then
      echo -e "${GREEN}   $MODEL_COUNT files in model cache${NC}"
    else
      echo -e "${YELLOW}⚠️ Model cache is empty${NC}"
    fi
  else
    echo -e "${RED}❌ Model cache volume not found${NC}"
    return 1
  fi

  return 0
}

# Run all checks
run_all_checks() {
  check_container

  local success=true

  if ! check_docker_cli; then
    success=false
  fi

  if ! check_network; then
    success=false
  fi

  if ! check_model_runner; then
    success=false
  fi

  if ! check_volumes; then
    success=false
  fi

  echo -e "\n${BLUE}=== Summary ===${NC}"
  if [ "$success" = true ]; then
    echo -e "${GREEN}✅ All checks passed successfully${NC}"
    echo -e "${GREEN}Docker Model Runner is properly configured${NC}"
    return 0
  else
    echo -e "${RED}❌ Some checks failed${NC}"
    echo -e "${YELLOW}Please review the issues above and fix them${NC}"
    return 1
  fi
}

# Main execution
run_all_checks