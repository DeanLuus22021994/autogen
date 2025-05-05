# DIR.TAG Pattern

## Pattern: Development Debt Tracking

**Purpose**: Standardize the tracking and documentation of development debt and implementation status across the project.

**When to use**:
- When creating new configuration directories
- When implementing features with multiple components
- When tracking outstanding tasks across directories
- When automating configuration management

**Implementation template**:

```plaintext
#INDEX: relative/path/to/directory
#TODO:
  - Task 1 description [STATUS]
  - Task 2 description [STATUS]
  - Task 3 description [STATUS]
status: STATUS
updated: YYYY-MM-DDTHH:MM:SSZ
description: |
  Multi-line description of the directory.
  Additional details about implementation status.
```

**Key considerations**:
- STATUS values should be one of: NOT_STARTED, PARTIALLY_COMPLETE, COMPLETE
- Task STATUS values should be one of: [OUTSTANDING], [IN_PROGRESS], [DONE]
- INDEX path should be relative to the project root
- Timestamp should be in ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ)
- Description should provide context for the directory's purpose

## Pattern: XML Configuration

**Purpose**: Provide a consistent, structured format for all configuration data with proper schema descriptions.

**When to use**:
- For all project configuration files
- When replacing legacy INI or plaintext config files
- When defining dictionaries, settings, or resources

**Implementation template**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<config_root_element>
  <section>
    <property>value</property>
    <nested_property>
      <item>value</item>
    </nested_property>
  </section>
  <list_section>
    <item>value1</item>
    <item>value2</item>
  </list_section>
</config_root_element>
```

**Key considerations**:
- Always include XML declaration with version and encoding
- Use a single root element
- Use descriptive element names in snake_case
- Avoid attributes when possible, prefer nested elements
- Include comments for complex properties
- No duplicate declarations
- Proper schema descriptions for all elements

## Integration with VS Code Tasks

These patterns are supported by dedicated VS Code tasks:

1. **Update DIR.TAG Files**: Automatically updates timestamps and ensures correct indexing
2. **Create New Config Directory**: Creates new directories with proper DIR.TAG structure
3. **Check DIR.TAG Consistency**: Validates all DIR.TAG files for proper format

Execute these tasks via the VS Code Command Palette (`Ctrl+Shift+P` → "Tasks: Run Task").
