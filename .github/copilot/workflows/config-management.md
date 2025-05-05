# Configuration Management Workflow

## Workflow: DIR.TAG Management

**Steps**:
1. Run "Update DIR.TAG Files" task to ensure all DIR.TAG files are up to date
2. Use "Check DIR.TAG Consistency" to validate the configuration structure
3. For new configuration directories, use "Create New Config Directory" task
4. Update development debt status in DIR.TAG files as tasks are completed
5. Ensure all configurations use XML format with proper schema descriptions

**Inputs required**:
- Directory path for new configuration (when creating)
- Development debt status updates (OUTSTANDING, IN_PROGRESS, DONE)
- Implementation description for documentation

**Expected outputs**:
- Consistent, machine-readable DIR.TAG files across the project
- Clear tracking of implementation status and development debt
- Git-tracked empty directories via .gitkeep files
- Properly structured XML configuration files

## Best Practices

1. Always run the consistency check before commits
2. Document development debt clearly in DIR.TAG files
3. Use XML for all configuration with proper schema descriptions
4. Keep the index paths accurate and up to date
5. Propagate updates to all related configuration directories

## Common Tasks

### Adding a New Configuration Type

```bash
# 1. Create the directory with proper DIR.TAG
.devcontainer/manage-dir-tags.sh --action create --dir .config/mynewconfig --verbose

# 2. Add XML configuration files to the directory
# Example: Create mynewconfig.xml with proper schema

# 3. Update DIR.TAG with specific development tasks
# Edit .config/mynewconfig/DIR.TAG

# 4. Run consistency check
.devcontainer/manage-dir-tags.sh --action check --verbose
```

### Updating Implementation Status

1. Edit the DIR.TAG file for the relevant directory
2. Update the status field to reflect current state
3. Mark individual TODO items as [DONE], [IN_PROGRESS], or [OUTSTANDING]
4. Run the "Update DIR.TAG Files" task to propagate changes

### Resolving Schema Validation Warnings

If you encounter "schema description may not be empty" warnings:

1. Ensure all XML files have proper schema descriptions
2. Check for duplicate XML declarations
3. Validate that all configuration follows the XML standard
4. Run the consistency check to verify fixes
