# AutoGen Environment Configuration

This folder contains scripts and configuration files to help set up and manage environment variables for AutoGen development, particularly for handling authentication with GitHub, Docker, and other services.

## Environment Variables

The following environment variables are used throughout the codebase:

### Repository Configuration

- `REPO_PATH`: The name of the repository (default: "autogen")

### GitHub Configuration
- `FORK_AUTOGEN_OWNER`: Your GitHub username (e.g., "DeanLuus22021994")
- `FORK_AUTOGEN_SSH_REPO_URL`: The HTTPS URL to your forked repository
- `FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN`: Your GitHub Personal Access Token (PAT)

### Docker Configuration
- `FORK_AUTOGEN_USER_DOCKER_USERNAME`: Your Docker Hub username
- `FORK_USER_DOCKER_ACCESS_TOKEN`: Your Docker Hub access token

### API Tokens
- `FORK_HUGGINGFACE_ACCESS_TOKEN`: Your Hugging Face access token

## Setup Scripts

### Windows
- `setup-environment.ps1`: Interactive script to set up environment variables on Windows
- `check-environment.ps1`: Script to verify that all required environment variables are set
- `fix-git-auth.ps1`: Script to fix Git authentication issues using environment variables

### Linux/Mac
- `setup-environment.sh`: Interactive script to set up environment variables on Linux/Mac
- `check-environment.sh`: Script to verify that all required environment variables are set
- `fix-git-auth.sh`: Script to fix Git authentication issues using environment variables

## Container Configuration
- `.env`: Environment variable definitions for the development container
- `prepare-git.ps1` / `prepare-git.sh`: Scripts to configure Git authentication when the container starts
- `startup.sh`: Script that runs when the container starts, configuring Git and other services

## Usage

### Setting Up Environment Variables

#### Windows
```powershell
# Navigate to the .devcontainer directory
cd .devcontainer

# Run the setup script
.\setup-environment.ps1
```

#### Linux/Mac
```bash
# Navigate to the .devcontainer directory
cd .devcontainer

# Make the script executable
chmod +x setup-environment.sh

# Run the setup script
./setup-environment.sh
```

### Fixing Git Authentication Issues

If you encounter Git authentication issues (e.g., "Permission denied (publickey)"), you can run the fix-git-auth script:

#### Windows
```powershell
# Navigate to the .devcontainer directory
cd .devcontainer

# Run the fix script
.\fix-git-auth.ps1
```

#### Linux/Mac
```bash
# Navigate to the .devcontainer directory
cd .devcontainer

# Make the script executable
chmod +x fix-git-auth.sh

# Run the fix script
./fix-git-auth.sh
```

### Checking Environment Setup

To verify that all required environment variables are properly set:

#### Windows
```powershell
# Navigate to the .devcontainer directory
cd .devcontainer

# Run the check script
.\check-environment.ps1
```

#### Linux/Mac
```bash
# Navigate to the .devcontainer directory
cd .devcontainer

# Make the script executable
chmod +x check-environment.sh

# Run the check script
./check-environment.sh
```

## GitHub Actions Validation

A GitHub Actions workflow is included (`validate-environment.yml`) that regularly validates all tokens and credentials to ensure they remain valid. This workflow runs weekly and can also be triggered manually from the Actions tab in your repository.

## For More Information

See the [ENVIRONMENT-SETUP.md](ENVIRONMENT-SETUP.md) document for detailed instructions on setting up environment variables.