# DIR.TAG Management System

## Overview

The DIR.TAG Management System provides automated tools for creating, updating, and maintaining consistent configuration files across the AutoGen project. This system helps track development debt, ensures machine-readable metadata, and simplifies the process of adding new configuration directories.

## Features

- Automatic propagation of DIR.TAG files across all .config directories
- Consistent format for tracking development debt and implementation status
- Machine-readable metadata for automation tools
- Easy creation of new configuration directories with proper structure
- Built-in validation to ensure consistency

## VS Code Tasks

The following tasks are available in VS Code:

- **Update DIR.TAG Files**: Updates all existing DIR.TAG files with the latest timestamp and ensures correct indexing
- **Create New Config Directory**: Creates a new configuration directory with properly structured DIR.TAG and .gitkeep files
- **Check DIR.TAG Consistency**: Validates all DIR.TAG files for consistency and reports any issues

## Using the Script Directly

The `manage-dir-tags.sh` script can also be run directly from the command line:

```bash
# Update all DIR.TAG files
.devcontainer/manage-dir-tags.sh --action update

# Create a new configuration directory
.devcontainer/manage-dir-tags.sh --action create --dir .config/newdir

# Check for consistency issues
.devcontainer/manage-dir-tags.sh --action check
```

## DIR.TAG Format

All DIR.TAG files follow this standardized format:

```
#INDEX: .config/dirname
#TODO:
  - Task 1 [STATUS]
  - Task 2 [STATUS]
  - Task 3 [STATUS]
status: STATUS
updated: YYYY-MM-DDTHH:MM:SSZ
description: |
  Multi-line description of the directory.
  Additional details about implementation status.
```

## Adding New Configuration

To add a new configuration directory:

1. Use the "Create New Config Directory" VS Code task
2. Enter the relative path of the new directory (e.g., `.config/myconfig`)
3. Edit the generated DIR.TAG file to add specific development tasks
4. Add your XML configuration files to the new directory

## Maintaining Consistency

Run the "Check DIR.TAG Consistency" task regularly to ensure all configuration is properly maintained.

## Development Best Practices

- Always run the "Update DIR.TAG Files" task before committing changes to configuration
- Document all development debt as TODO items in the DIR.TAG files
- Use XML for all configuration data
- Include .gitkeep files in all directories for proper Git tracking
