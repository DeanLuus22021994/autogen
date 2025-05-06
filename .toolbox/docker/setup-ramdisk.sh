#!/bin/bash
# filepath: c:\Projects\autogen\.toolbox\docker\setup-ramdisk.sh
# Setup RAM disk for high-performance model inference with smoll2

set -e

# Default settings - can be overridden by environment variables
RAMDISK_SIZE=${RAMDISK_SIZE:-"8G"}
RAMDISK_MOUNT_POINT=${RAMDISK_MOUNT_POINT:-"/mnt/ramdisk"}
MODEL_CACHE_PATH=${MODEL_CACHE_PATH:-"/opt/autogen/models"}
MODEL_NAME=${MODEL_NAME:-"smoll2"}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up RAM disk for high-performance LLM inference with ${MODEL_NAME}${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root${NC}"
  echo "Please run with sudo or as root user"
  exit 1
fi

# Check if the mount point exists, create if it doesn't
if [ ! -d "$RAMDISK_MOUNT_POINT" ]; then
  echo -e "${YELLOW}Creating mount point directory: $RAMDISK_MOUNT_POINT${NC}"
  mkdir -p $RAMDISK_MOUNT_POINT
fi

# Check if a RAM disk is already mounted at the specified location
if mount | grep -q "$RAMDISK_MOUNT_POINT"; then
  echo -e "${YELLOW}RAM disk already mounted at $RAMDISK_MOUNT_POINT${NC}"
  echo -e "Current RAM disk usage:"
  df -h $RAMDISK_MOUNT_POINT
else
  # Mount the RAM disk using tmpfs
  echo -e "${GREEN}Mounting RAM disk of size $RAMDISK_SIZE at $RAMDISK_MOUNT_POINT${NC}"
  mount -t tmpfs -o size=$RAMDISK_SIZE,mode=1777 tmpfs $RAMDISK_MOUNT_POINT

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully mounted RAM disk${NC}"
    echo -e "RAM disk usage:"
    df -h $RAMDISK_MOUNT_POINT
  else
    echo -e "${RED}Failed to mount RAM disk${NC}"
    exit 1
  fi
fi

# Create directory structure for model cache
MODEL_DIR="$RAMDISK_MOUNT_POINT/${MODEL_NAME}"
if [ ! -d "$MODEL_DIR" ]; then
  echo -e "${GREEN}Creating model directory: $MODEL_DIR${NC}"
  mkdir -p $MODEL_DIR
  chmod 777 $MODEL_DIR
fi

# Check if we need to create a symlink to the model cache
if [ "$MODEL_CACHE_PATH" != "$MODEL_DIR" ]; then
  # Check if the model cache directory exists
  if [ ! -d "$MODEL_CACHE_PATH" ]; then
    echo -e "${YELLOW}Creating model cache directory: $MODEL_CACHE_PATH${NC}"
    mkdir -p $MODEL_CACHE_PATH
  fi

  # Create a symlink from the RAM disk to the model cache location for the specific model
  MODEL_CACHE_TARGET="$MODEL_CACHE_PATH/${MODEL_NAME}"
  if [ -L "$MODEL_CACHE_TARGET" ]; then
    echo -e "${YELLOW}Removing existing symlink: $MODEL_CACHE_TARGET${NC}"
    rm -f "$MODEL_CACHE_TARGET"
  elif [ -d "$MODEL_CACHE_TARGET" ]; then
    echo -e "${YELLOW}Moving existing model data to RAM disk...${NC}"
    cp -r "$MODEL_CACHE_TARGET"/* "$MODEL_DIR/" 2>/dev/null || true
    echo -e "${YELLOW}Removing existing directory: $MODEL_CACHE_TARGET${NC}"
    rm -rf "$MODEL_CACHE_TARGET"
  fi

  echo -e "${GREEN}Creating symlink from $MODEL_DIR to $MODEL_CACHE_TARGET${NC}"
  ln -sf "$MODEL_DIR" "$MODEL_CACHE_TARGET"
fi

echo -e "${GREEN}RAM disk setup completed for ${MODEL_NAME}${NC}"
echo -e "${YELLOW}Add the following to your Docker/Docker Swarm configuration:${NC}"
echo -e "volumes:"
echo -e "  - ${RAMDISK_MOUNT_POINT}:${MODEL_CACHE_PATH}"
echo -e "environment:"
echo -e "  - MODEL_PATH=${MODEL_CACHE_PATH}/${MODEL_NAME}"

# Add to fstab if requested
if [ "$ADD_TO_FSTAB" = "true" ]; then
  echo -e "${YELLOW}Adding RAM disk to /etc/fstab for persistence across reboots${NC}"
  # Check if entry already exists
  if grep -q "$RAMDISK_MOUNT_POINT" /etc/fstab; then
    echo -e "${YELLOW}RAM disk entry already exists in /etc/fstab${NC}"
  else
    echo -e "# RAM disk for high-performance LLM inference" >> /etc/fstab
    echo -e "tmpfs $RAMDISK_MOUNT_POINT tmpfs size=$RAMDISK_SIZE,mode=1777 0 0" >> /etc/fstab
    echo -e "${GREEN}Added RAM disk entry to /etc/fstab${NC}"
  fi
fi

exit 0
