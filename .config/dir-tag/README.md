# DIR.TAG and Problems Integration

This configuration directory contains settings for integrating DIR.TAG files with problem tracking in the AutoGen project.

## Configuration Files

- `dir-tag-schema.json`: JSON schema for validating DIR.TAG files
- `problem-tracking.json`: Configuration for mapping problem states to DIR.TAG status values
- `sync-settings.json`: Settings for the synchronization process

## Integration with VS Code

The toolbox provides VS Code tasks for managing DIR.TAG files and tracking development progress across the project.

## Usage

Run the `Sync-DirTagConfig.ps1` script to synchronize DIR.TAG files:

```powershell
pwsh -File .toolbox/config/Sync-DirTagConfig.ps1 -UpdateAll
```

## Problems Integration

The integration with problems tracking allows:

1. Automatic status updates based on open issues/problems
2. Tracking development progress through DIR.TAG status values
3. Reporting on project health and completion status

## Related Tasks

- `Update DIR.TAG Files`: Updates all DIR.TAG files with proper GUIDs
- `Check DIR.TAG Consistency`: Validates the structure of all DIR.TAG files
- `Create New Config Directory`: Creates a new configuration directory with a DIR.TAG file
