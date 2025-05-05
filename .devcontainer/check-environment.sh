#!/bin/bash

# This script checks if all required environment variables are properly set

check_env_var() {
    if [ -z "${!1}" ]; then
        echo -e "\e[31m$1 is not set\e[0m"
        return 1
    else
        echo -e "\e[32m$1 is set\e[0m"
        return 0
    fi
}

echo -e "\e[36mChecking AutoGen Environment Variables\e[0m"
echo -e "\e[36m=====================================\e[0m"

# Check repository configuration
check_env_var "REPO_PATH"

# Check GitHub configuration
check_env_var "FORK_AUTOGEN_OWNER"
check_env_var "FORK_AUTOGEN_SSH_REPO_URL"
github_token_set=0
check_env_var "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN" && github_token_set=1

# Check Docker configuration
check_env_var "FORK_AUTOGEN_USER_DOCKER_USERNAME"
docker_token_set=0
check_env_var "FORK_USER_DOCKER_ACCESS_TOKEN" && docker_token_set=1

# Check API tokens
hf_token_set=0
check_env_var "FORK_HUGGINGFACE_ACCESS_TOKEN" && hf_token_set=1

echo ""

# Test GitHub connectivity if token is set
if [ $github_token_set -eq 1 ]; then
    echo -e "\e[36mTesting GitHub connectivity...\e[0m"
    if git ls-remote "https://$FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN@github.com/$FORK_AUTOGEN_OWNER/$REPO_PATH.git" HEAD &>/dev/null; then
        echo -e "\e[32mGitHub connection successful!\e[0m"
    else
        echo -e "\e[31mGitHub connection failed. Please check your credentials.\e[0m"
    fi
fi

# Test Docker connectivity if token is set
if [ $docker_token_set -eq 1 ] && [ -n "$FORK_AUTOGEN_USER_DOCKER_USERNAME" ]; then
    echo -e "\e[36mTesting Docker connectivity...\e[0m"
    if echo "$FORK_USER_DOCKER_ACCESS_TOKEN" | docker login --username "$FORK_AUTOGEN_USER_DOCKER_USERNAME" --password-stdin &>/dev/null; then
        echo -e "\e[32mDocker login successful!\e[0m"
        docker logout &>/dev/null
    else
        echo -e "\e[31mDocker login failed. Please check your credentials.\e[0m"
    fi
fi
