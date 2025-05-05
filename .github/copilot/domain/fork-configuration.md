---
applyTo: '**/.github/workflows/*.yml'
---

# Fork Configuration Details

This document outlines the specific configuration details for the DeanLuus22021994 fork of the AutoGen repository. This information is essential for properly configuring workflows, automation, and development tools.

## Environment Variables

The following environment variables are configured in the repository and GitHub Actions secrets:

| Variable Name | Description | Usage Context |
|---------------|-------------|---------------|
| `REPO_PATH` | Root path of the repository, set to "autogen" | File path references in scripts and workflows |
| `FORK_AUTOGEN_OWNER` | GitHub username: DeanLuus22021994 | Repository ownership references |
| `FORK_AUTOGEN_SSH_REPO_URL` | Repository URL | Git operations and cloning |
| `FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN` | GitHub personal access token | Authentication for GitHub API calls and git operations |
| `FORK_AUTOGEN_USER_DOCKER_USERNAME` | Docker Hub username: deanluus22021994 | Docker image publishing |
| `FORK_USER_DOCKER_ACCESS_TOKEN` | Docker Hub access token | Authentication for Docker registry operations |
| `FORK_HUGGINGFACE_ACCESS_TOKEN` | Hugging Face API token | Authentication for Hugging Face API calls |

## Authentication Validation

Workflows should validate the presence and validity of these credentials before performing operations that require authentication:

```yaml
# Example validation step
- name: Validate credentials
  run: |
    if [ -z "${{ secrets.FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN }}" ]; then
      echo "::error::GitHub token is not set"
      exit 1
    fi
    if [ -z "${{ secrets.FORK_USER_DOCKER_ACCESS_TOKEN }}" ]; then
      echo "::error::Docker token is not set"
      exit 1
    fi
    if [ -z "${{ secrets.FORK_HUGGINGFACE_ACCESS_TOKEN }}" ]; then
      echo "::error::Hugging Face token is not set"
      exit 1
    fi
```

## IDE Problem References

* `#problems`: Flag environment variable issues or inconsistent usage
* `#security`: Mark code that needs to handle tokens securely
* `#todo`: Identify missing validation or configuration
* `#fixme`: Highlight broken authentication flows

## Best Practices

1. Never hardcode tokens or credentials in workflows or scripts
2. Use GitHub repository secrets for all sensitive values
3. Validate credential presence before attempting authenticated operations
4. Provide meaningful error messages when credentials are missing or invalid
5. Use environment variables consistently across all workflows

## References

* [GitHub Actions Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
* [Docker Hub Authentication Documentation](https://docs.docker.com/docker-hub/access-tokens/)
* [Hugging Face API Documentation](https://huggingface.co/docs/api-inference/quicktour)
