#!/bin/bash
# manage-dir-tags.sh
# Purpose: Automate the creation, update, and propagation of DIR.TAG files across the project.
# This ensures consistent development debt tracking and machine-readable configuration.

set -e

# Default values
ROOT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")/.."
CONFIG_DIR="${ROOT_DIR}/.config"
DIRTAG_PATTERN="DIR.TAG"
GITKEEP=".gitkeep"
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ACTION="update"
VERBOSE=0
TARGET_DIR=""

# Display help information
function show_help() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -h, --help             Show this help message"
  echo "  -v, --verbose          Enable verbose output"
  echo "  -a, --action ACTION    Action to perform: update, create, check"
  echo "  -d, --dir DIRECTORY    Target specific directory"
  echo "  -r, --root DIRECTORY   Set root directory (default: project root)"
  echo ""
  echo "Examples:"
  echo "  $0 --action update                  # Update all DIR.TAG files"
  echo "  $0 --action create --dir .config/newdir  # Create a new DIR.TAG in specified directory"
  echo "  $0 --action check                   # Check for consistency issues"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
      show_help
      exit 0
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -a|--action)
      ACTION="$2"
      shift
      shift
      ;;
    -d|--dir)
      TARGET_DIR="$2"
      shift
      shift
      ;;
    -r|--root)
      ROOT_DIR="$(realpath "$2")"
      CONFIG_DIR="${ROOT_DIR}/.config"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Function to log verbose information
function log() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "$@"
  fi
}

# Function to create a new DIR.TAG file
function create_dir_tag() {
  local dir="$1"
  local relative_path="${dir#$ROOT_DIR/}"
  local tag_file="$dir/$DIRTAG_PATTERN"
  local gitkeep_file="$dir/$GITKEEP"

  # Ensure .gitkeep exists
  if [ ! -f "$gitkeep_file" ]; then
    touch "$gitkeep_file"
    log "Created $gitkeep_file"
  fi

  # If DIR.TAG does not exist, create a new one
  if [ ! -f "$tag_file" ]; then
    cat > "$tag_file" <<EOF
#INDEX: ${relative_path}
#TODO:
  - Implement configuration standards [OUTSTANDING]
  - Document usage and schema [OUTSTANDING]
  - Add integration tests [OUTSTANDING]
status: NOT_STARTED
updated: ${CURRENT_DATE}
description: |
  Configuration directory for ${relative_path}.
  Outstanding: Define XML schemas and integration.
EOF
    log "Created new DIR.TAG in $dir"
  else
    log "DIR.TAG already exists in $dir"
  fi
}

# Function to update an existing DIR.TAG file
function update_dir_tag() {
  local dir="$1"
  local relative_path="${dir#$ROOT_DIR/}"
  local tag_file="$dir/$DIRTAG_PATTERN"
  local gitkeep_file="$dir/$GITKEEP"

  # Ensure .gitkeep exists
  if [ ! -f "$gitkeep_file" ]; then
    touch "$gitkeep_file"
    log "Created $gitkeep_file"
  fi

  # If DIR.TAG does not exist, create it
  if [ ! -f "$tag_file" ]; then
    create_dir_tag "$dir"
    return
  fi

  # Update the existing DIR.TAG file
  local temp_file="${tag_file}.tmp"
  awk -v dir="$relative_path" -v now="$CURRENT_DATE" '
    BEGIN { found_index=0; found_updated=0; }
    /^#INDEX:/ { print "#INDEX: " dir; found_index=1; next }
    /^updated:/ { print "updated: " now; found_updated=1; next }
    { print }
    END {
      if (!found_index) print "#INDEX: " dir;
      if (!found_updated) print "updated: " now;
    }
  ' "$tag_file" > "$temp_file" && mv "$temp_file" "$tag_file"

  log "Updated DIR.TAG in $dir"
}

# Function to check DIR.TAG files for consistency issues
function check_dir_tag() {
  local dir="$1"
  local relative_path="${dir#$ROOT_DIR/}"
  local tag_file="$dir/$DIRTAG_PATTERN"
  local gitkeep_file="$dir/$GITKEEP"
  local issues=0

  if [ ! -f "$gitkeep_file" ]; then
    echo "WARNING: Missing .gitkeep in $dir"
    issues=$((issues + 1))
  fi

  if [ ! -f "$tag_file" ]; then
    echo "WARNING: Missing DIR.TAG in $dir"
    issues=$((issues + 1))
  else
    # Check for required fields
    if ! grep -q "^#INDEX:" "$tag_file"; then
      echo "ERROR: Missing #INDEX in $tag_file"
      issues=$((issues + 1))
    fi

    if ! grep -q "^#TODO:" "$tag_file"; then
      echo "ERROR: Missing #TODO in $tag_file"
      issues=$((issues + 1))
    fi

    if ! grep -q "^status:" "$tag_file"; then
      echo "ERROR: Missing status in $tag_file"
      issues=$((issues + 1))
    fi

    if ! grep -q "^updated:" "$tag_file"; then
      echo "ERROR: Missing updated timestamp in $tag_file"
      issues=$((issues + 1))
    fi

    if ! grep -q "^description:" "$tag_file"; then
      echo "ERROR: Missing description in $tag_file"
      issues=$((issues + 1))
    fi

    # Check for correct index
    local index=$(grep "^#INDEX:" "$tag_file" | sed 's/^#INDEX: *//')
    if [ "$index" != "$relative_path" ]; then
      echo "ERROR: Incorrect #INDEX in $tag_file (is: $index, should be: $relative_path)"
      issues=$((issues + 1))
    fi
  fi

  return $issues
}

# Function to process directories recursively
function process_directories() {
  local action_func="$1"
  local start_dir="$2"

  find "$start_dir" -type d ! -path "*/\.*" ! -path "*/node_modules/*" | while read -r dir; do
    "$action_func" "$dir"
  done
}

# Main execution logic
if [ -n "$TARGET_DIR" ]; then
  # Process a specific directory
  target_full_path="$ROOT_DIR/$TARGET_DIR"
  if [ ! -d "$target_full_path" ]; then
    mkdir -p "$target_full_path"
    log "Created directory: $target_full_path"
  fi

  case "$ACTION" in
    create)
      create_dir_tag "$target_full_path"
      ;;
    update)
      update_dir_tag "$target_full_path"
      ;;
    check)
      check_dir_tag "$target_full_path"
      ;;
    *)
      echo "Unknown action: $ACTION"
      show_help
      exit 1
      ;;
  esac
else
  # Process .config directory and its subdirectories
  case "$ACTION" in
    create|update)
      action_func="update_dir_tag"
      if [ "$ACTION" = "create" ]; then
        action_func="create_dir_tag"
      fi

      # First ensure the .config directory exists
      if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        log "Created directory: $CONFIG_DIR"
      fi

      # Process .config directory
      process_directories "$action_func" "$CONFIG_DIR"
      echo "Successfully processed all directories in $CONFIG_DIR"
      ;;
    check)
      issues=0
      while IFS= read -r dir; do
        check_dir_tag "$dir" || issues=$((issues + $?))
      done < <(find "$CONFIG_DIR" -type d ! -path "*/\.*" ! -path "*/node_modules/*")

      if [ $issues -eq 0 ]; then
        echo "All DIR.TAG files are consistent."
        exit 0
      else
        echo "Found $issues issue(s) in DIR.TAG files."
        exit 1
      fi
      ;;
    *)
      echo "Unknown action: $ACTION"
      show_help
      exit 1
      ;;
  esac
fi

exit 0
