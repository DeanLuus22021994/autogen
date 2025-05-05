#!/bin/bash
# propagate-dir-tags.sh
# Scans all .devcontainer/**/DIR.TAG files, updates #TODO and #INDEX tags, and ensures .gitkeep files exist.

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
DIRTAG_PATTERN="DIR.TAG"
GITKEEP=".gitkeep"

function update_dir_tag() {
  local dir="$1"
  local tag_file="$dir/$DIRTAG_PATTERN"
  local gitkeep_file="$dir/$GITKEEP"

  # Ensure .gitkeep exists
  if [ ! -f "$gitkeep_file" ]; then
    touch "$gitkeep_file"
  fi

  # If DIR.TAG does not exist, create a default one
  if [ ! -f "$tag_file" ]; then
    cat > "$tag_file" <<EOF
#INDEX: $dir
#TODO: NEW
status: NOT_STARTED
updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
description: "No implementation details yet."
EOF
    return
  fi

  # Update existing DIR.TAG: refresh timestamp, ensure #INDEX and #TODO present
  awk -v dir="$dir" -v now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '
    BEGIN { found_index=0; found_todo=0; }
    /^#INDEX:/ { print "#INDEX: " dir; found_index=1; next }
    /^#TODO:/ { found_todo=1; print; next }
    /^updated:/ { print "updated: " now; next }
    { print }
    END {
      if (!found_index) print "#INDEX: " dir;
      if (!found_todo) print "#TODO: UNKNOWN";
    }
  ' "$tag_file" > "$tag_file.tmp" && mv "$tag_file.tmp" "$tag_file"
}

export -f update_dir_tag

# Find all directories under .devcontainer (excluding .git, node_modules, etc.)
find "$ROOT_DIR" -type d ! -path "*/\.*" | while read -r dir; do
  update_dir_tag "$dir"
done

echo "DIR.TAG propagation and update complete."
