#!/bin/bash

# This script helps set up the required environment variables for AutoGen development on Linux/Mac

# Function to validate input is not empty
validate_input() {
    if [ -z "$1" ]; then
        echo -e "\e[31m$2\e[0m"
        return 1
    fi
    return 0
}

# Function to set an environment variable in the shell profile
set_env_var() {
    local name=$1
    local value=$2
    local shell_profile=""

    # Determine shell profile file
    if [ -n "$ZSH_VERSION" ]; then
        shell_profile="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_profile="$HOME/.bashrc"
    else
        # Try to guess based on default shell
        shell=$(basename "$SHELL")
        if [ "$shell" = "zsh" ]; then
            shell_profile="$HOME/.zshrc"
        else
            shell_profile="$HOME/.bashrc"
        fi
    fi

    # Check if the variable already exists in the profile
    if grep -q "export $name=" "$shell_profile"; then
        # Replace the existing value
        sed -i.bak "s|export $name=.*|export $name=\"$value\"|g" "$shell_profile"
    else
        # Add the new variable
        echo "export $name=\"$value\"" >> "$shell_profile"
    fi

    # Also set for current session
    export "$name"="$value"
    echo -e "\e[32mEnvironment variable $name has been set in $shell_profile\e[0m"
}

echo -e "\e[36mAutoGen Environment Setup\e[0m"
echo -e "\e[36m=========================\e[0m"
echo "This script will set up the required environment variables for working with AutoGen."
echo -e "\e[33mLeave a field blank to skip setting that variable.\e[0m"
echo ""

# Get GitHub username
read -p "Enter your GitHub username (e.g., DeanLuus22021994): " github_username
if validate_input "$github_username" "GitHub username is required."; then
    set_env_var "FORK_AUTOGEN_OWNER" "$github_username"
fi

# Get GitHub personal access token
read -sp "Enter your GitHub Personal Access Token (PAT): " github_token
echo ""
if validate_input "$github_token" "GitHub Personal Access Token is required."; then
    set_env_var "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN" "$github_token"
fi

# Get Docker username
read -p "Enter your Docker Hub username: " docker_username
if validate_input "$docker_username" "Docker Hub username is required."; then
    set_env_var "FORK_AUTOGEN_USER_DOCKER_USERNAME" "$docker_username"
fi

# Get Docker access token
read -sp "Enter your Docker Hub access token: " docker_token
echo ""
if validate_input "$docker_token" "Docker Hub access token is required."; then
    set_env_var "FORK_USER_DOCKER_ACCESS_TOKEN" "$docker_token"
fi

# Get Hugging Face access token
read -sp "Enter your Hugging Face access token: " hf_token
echo ""
if validate_input "$hf_token" "Hugging Face access token is required."; then
    set_env_var "FORK_HUGGINGFACE_ACCESS_TOKEN" "$hf_token"
fi

# Set repository path
set_env_var "REPO_PATH" "autogen"

# Set repository URL
repo_url="https://github.com/$github_username/autogen"
set_env_var "FORK_AUTOGEN_SSH_REPO_URL" "$repo_url"

echo ""
echo -e "\e[32mEnvironment variables have been set successfully.\e[0m"
echo -e "\e[33mYou need to restart your terminal or source your shell profile for the changes to take effect.\e[0m"
echo ""
echo -e "\e[36mTesting GitHub connectivity...\e[0m"

# Test GitHub connectivity using the token
if git ls-remote "https://$github_token@github.com/$github_username/autogen.git" HEAD &>/dev/null; then
    echo -e "\e[32mGitHub connection successful!\e[0m"
else
    echo -e "\e[31mGitHub connection failed. Please check your credentials.\e[0m"
fi
