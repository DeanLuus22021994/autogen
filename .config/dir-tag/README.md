# DIR.TAG Integration with Toolbox

This configuration directory contains settings for integrating DIR.TAG files with problem tracking in the AutoGen project.

## Configuration Files

- `dir-tag-schema.xml`: XML schema for validating DIR.TAG files
- `dir-tag-config.xml`: Configuration for mapping problem states to DIR.TAG status values

## Integration with VS Code

The toolbox provides VS Code tasks for managing DIR.TAG files and tracking development progress across the project:

- **Update DIR.TAG Files**: Synchronizes all DIR.TAG files with the latest configuration
- **Sync DIR.TAG with Problems**: Updates DIR.TAG status based on detected problems
- **Generate DIR.TAG Report**: Creates a report on project status and completion

## Usage

Run the `Sync-DirTagConfig.ps1` script to synchronize DIR.TAG files:

```powershell
pwsh -File .toolbox/config/Sync-DirTagConfig.ps1 -UpdateAll
```

## GUID-Based Tracking

Each DIR.TAG file includes a GUID to uniquely identify it for state tracking purposes. This allows:

1. Tracking status changes over time
2. Ensuring files maintain their identity even if moved
3. Proper integration with problem management

## Related Tasks

- `Update DIR.TAG Files`: Updates all DIR.TAG files with proper GUIDs
- `Check DIR.TAG Consistency`: Validates the structure of all DIR.TAG files
- `Create New Config Directory`: Creates a new configuration directory with a DIR.TAG file
