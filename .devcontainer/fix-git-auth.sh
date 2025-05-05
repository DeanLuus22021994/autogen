#!/bin/bash

# This script fixes Git authentication issues using environment variables

echo -e "\e[36mSetting up Git authentication for AutoGen repository...\e[0m"

# Check if environment variables are set
if [ -z "$FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN" ]; then
    echo -e "\e[31mError: FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN is not set.\e[0m"
    echo "Please run the setup-environment.sh script or set this environment variable manually."
    exit 1
fi

if [ -z "$FORK_AUTOGEN_OWNER" ]; then
    echo -e "\e[31mError: FORK_AUTOGEN_OWNER is not set.\e[0m"
    echo "Please run the setup-environment.sh script or set this environment variable manually."
    exit 1
fi

# Configure Git to use HTTPS with personal access token
git config --global url."https://$FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN@github.com/$FORK_AUTOGEN_OWNER".insteadOf "git@github.com:$FORK_AUTOGEN_OWNER"
git config --global url."https://$FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN@github.com/$FORK_AUTOGEN_OWNER".insteadOf "https://github.com/$FORK_AUTOGEN_OWNER"

echo -e "\e[32mGit configured to use HTTPS with personal access token for $FORK_AUTOGEN_OWNER repositories\e[0m"

# Verify the connection
echo -e "\e[36mTesting GitHub connection...\e[0m"
if [ -z "$REPO_PATH" ]; then
    REPO_PATH="autogen"
fi

if git ls-remote "https://$FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN@github.com/$FORK_AUTOGEN_OWNER/$REPO_PATH.git" HEAD &>/dev/null; then
    echo -e "\e[32mGitHub connection successful!\e[0m"
else
    echo -e "\e[31mGitHub connection failed. Please check your credentials.\e[0m"
fi
