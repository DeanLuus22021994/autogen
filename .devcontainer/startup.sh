#!/bin/bash

# Setup Git configuration for repository access
echo "Setting up Git configuration..."
if [ -f ".devcontainer/prepare-git.sh" ]; then
    chmod +x .devcontainer/prepare-git.sh
    .devcontainer/prepare-git.sh
fi

# dotnet setup
dotnet workload update
dotnet dev-certs https --trust

# python setup
pushd python
pip install uv
uv sync
source .venv/bin/activate
echo "export PATH=$PATH" >> ~/.bashrc
popd

# Setup Docker credentials if available
if [ -n "$FORK_USER_DOCKER_ACCESS_TOKEN" ] && [ -n "$FORK_AUTOGEN_USER_DOCKER_USERNAME" ]; then
    echo "Setting up Docker credentials..."
    echo "$FORK_USER_DOCKER_ACCESS_TOKEN" | docker login --username "$FORK_AUTOGEN_USER_DOCKER_USERNAME" --password-stdin
fi
