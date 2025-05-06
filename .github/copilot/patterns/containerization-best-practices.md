# Pattern: Containerization Best Practices

**Purpose**: Ensure all containerized development is portable, maintainable, and high-performance.

**When to use**: Any time you are building, configuring, or documenting Docker/DevContainer/Swarm environments.

**Implementation template**:
- Always use repository-relative paths (never absolute).
- Use named volumes for persistent and cache data.
- Pre-cache VS Code extensions (e.g., Vim) using a shared volume and post-create script.
- Document all container-specific tasks in DIR.TAG files.
- Modularize all scripts and configs (SRP/DRY).

**Key considerations**:
- Never hardcode absolute paths.
- Document extension pre-caching in both code and DIR.TAG.
- Use micro-modular scripts for each container concern.
