# Pattern: VS Code Extension Pre-caching

**Purpose**: Speed up container startup and ensure consistent dev environments by pre-caching extensions.

**When to use**: In all devcontainer and Docker-based development environments.

**Implementation template**:
- Add a named volume for VS Code extensions in `docker-compose.yml`.
- Add `"mounts"` for extensions in `devcontainer.json`.
- Add a `post-create.sh` script to install required extensions (e.g., Vim).
- Add a DIR.TAG task: "Pre-cache VS Code extensions (including Vim) for containerized development [OUTSTANDING]".

**Key considerations**:
- Use only repository-relative paths.
- Document the pattern in DIR.TAG and documentation.
