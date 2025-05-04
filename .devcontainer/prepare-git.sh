#!/bin/bash

# Load environment variables
if [ -f ".devcontainer/.env" ]; then
  source .devcontainer/.env
fi

# Configure Git to use HTTPS with personal access token
if [ -n "$FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN" ]; then
  # Extract owner and repo name from the URL
  OWNER=${FORK_AUTOGEN_OWNER}

  # Configure Git to use HTTPS with the token
  git config --global url."https://${FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}@github.com/${OWNER}".insteadOf "git@github.com:${OWNER}"
  git config --global url."https://${FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}@github.com/${OWNER}".insteadOf "https://github.com/${OWNER}"

  echo "Git configured to use HTTPS with personal access token for ${OWNER} repositories"
else
  echo "Warning: FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN is not set. You may encounter authentication issues."
fi

# Configure Git user information if needed
if [ -z "$(git config --global user.email)" ]; then
  echo "Setting up Git user email and name..."
  git config --global user.email "github-actions@github.com"
  git config --global user.name "GitHub Actions"
fi

# Verify the connection
echo "Testing GitHub connection..."
git ls-remote https://github.com/${FORK_AUTOGEN_OWNER}/${REPO_PATH}.git HEAD
if [ $? -eq 0 ]; then
  echo "GitHub connection successful!"
else
  echo "GitHub connection failed. Please check your credentials."
fi