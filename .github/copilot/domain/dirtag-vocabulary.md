## Domain Vocabulary: DIR.TAG System

| Term | Definition | Example Usage |
|------|------------|---------------|
| **DIR.TAG** | Special file used to track development status and technical debt in directories | `#INDEX: C:/Projects/autogen/.devcontainer` |
| **DIR.TAG Group** | Collection of related DIR.TAG files managed together | GPU Configuration Group containing Docker and Swarm DIR.TAG files |
| **DIR.TAG Operation** | Action performed on DIR.TAG files (Add, Remove, Update, etc.) | Adding a new TODO item to a group of DIR.TAG files |
| **TODO Item** | Task entry in DIR.TAG file with description and status | `Implement GPU passthrough [DONE]` |
| **Status** | Current state of a task or directory (NOT_STARTED, OUTSTANDING, PARTIALLY_COMPLETE, DONE) | `status: PARTIALLY_COMPLETE` |
| **GUID** | Globally Unique Identifier for each DIR.TAG file | `#GUID: 0e9c49cb-6c30-49e3-99df-42a073913a3b` |
| **INDEX** | Path reference for the directory containing the DIR.TAG file | `#INDEX: C:/Projects/autogen/.toolbox/docker` |
| **RAM Disk** | Memory-based virtual disk for high-performance file operations | Used to store model weights for faster inference |
| **DirTagGroupOperation** | Enumeration of operations for DIR.TAG group management | `Add`, `Remove`, `Update`, `SetStatus`, `Validate`, `Propagate`, `Reorganize`, `Sync` |
| **DirTagStatusCode** | Error/status codes for DIR.TAG operations | `Success`, `FileNotFound`, `AccessDenied`, etc. |
