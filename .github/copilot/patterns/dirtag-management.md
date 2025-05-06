# DIR.TAG Management Pattern

**Purpose**: Track development status and technical debt at the directory level.

**When to use**: In any directory where you want to document requirements, progress, or TODOs.

---

## Implementation Template

```plaintext
#INDEX: [directory-path]
#TODO:
  - [Task description] [STATUS]
  - [Task description] [STATUS]
  - ...
status: [OVERALL_STATUS]
updated: [YYYY-MM-DDThh:mm:ssZ]
description: |
  [Detailed description of the directory purpose]
  [Additional context and information]
```

---

## Status Values

- `NOT_STARTED`: Task has been identified but no work has begun
- `OUTSTANDING`: Task is known but not currently being addressed
- `PARTIALLY_COMPLETE`: Task is in progress
- `DONE`: Task has been completed

---

## Implementation Approach

1. **Centralized Management**

   ```powershell
   # Create a DIR.TAG group for related components
   $group = New-DirTagGroup -Name "ComponentGroup" -DirectoryPaths @(
       "$repoRoot/component1",
       "$repoRoot/component2"
   )

   # Apply operations to the entire group
   Invoke-DirTagGroupOperation -Group $group -Operation Add -TodoItem "Implement feature X [OUTSTANDING]"
   ```

2. **Task Status Updates**

   ```powershell
   # Update task status across a group
   Invoke-DirTagGroupOperation -Group $group -Operation Update -TodoItem "Implement feature X" -Status "DONE"
   ```

3. **Standardized Directory Creation**

   ```powershell
   # Create a new directory with standard DIR.TAG
   New-DirTag -DirectoryPath "$repoRoot/new-component" -Description "New component for feature X" -TodoItems @(
       "Implement core functionality [OUTSTANDING]",
       "Add unit tests [OUTSTANDING]",
       "Document API [OUTSTANDING]"
   )
   ```

---

## Key Considerations

- Every directory should have a DIR.TAG file for tracking purposes.
- Status should be kept up-to-date as implementation progresses.
- Groups of related components should have synchronized status updates.
- DIR.TAG files should be checked into version control.
- Automated tools should be used to validate DIR.TAG consistency.
- Pipeline integration should validate DIR.TAG formatting.

---

## Best Practices

- Use descriptive task descriptions that clearly indicate the work required.
- Update status consistently as work progresses.
- Include enough detail in the description to understand the directory's purpose.
- Organize related tasks with consistent naming across components.
- Use automation for bulk updates to maintain consistency.
- Leverage the GUID for unique identification in tooling integrations.

---

## References

- See `.github/copilot/domain/dirtag-vocabulary.md` for terminology.
- See `.github/copilot/patterns/extension-precaching.md` for extension pre-caching pattern.
- See `.github/copilot/workflows/dir-tag-validation.md` for validation workflow.
