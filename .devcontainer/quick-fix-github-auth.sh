#!/bin/bash

# This script is now a legacy wrapper that redirects to either auto-fix-git-auth.sh or setup-environment.sh

echo -e "\e[33mNote: quick-fix-github-auth.sh is now deprecated.\e[0m"
echo -e "\e[36mWe recommend using one of the following scripts instead:\e[0m"
echo ""
echo -e "\e[32m1. For automatic fix with no prompts:\e[0m"
echo -e "\e[36m   ./auto-fix-git-auth.sh\e[0m"
echo ""
echo -e "\e[32m2. For interactive setup with prompts:\e[0m"
echo -e "\e[36m   ./setup-environment.sh\e[0m"
echo ""

read -p "Which script would you like to run? (1=auto, 2=interactive, or press Enter for auto): " script_choice

if [ -z "$script_choice" ] || [ "$script_choice" = "1" ]; then
    echo -e "\e[32mRunning automatic fix script...\e[0m"
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    "$SCRIPT_DIR/auto-fix-git-auth.sh"
elif [ "$script_choice" = "2" ]; then
    echo -e "\e[32mRunning interactive setup script...\e[0m"
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    "$SCRIPT_DIR/setup-environment.sh"
else
    echo -e "\e[31mInvalid choice. Exiting.\e[0m"
    exit 1
fi

configure_git_credentials() {
    local token=$1
    local owner=$2

    echo -e "\e[36mConfiguring Git to use HTTPS with personal access token...\e[0m"

    # Configure Git to use HTTPS with personal access token
    git config --global url."https://$token@github.com/$owner".insteadOf "git@github.com:$owner"
    git config --global url."https://$token@github.com/$owner".insteadOf "https://github.com/$owner"

    echo -e "\e[32m✓ Git configured to use HTTPS with personal access token for $owner repositories\e[0m"
}

# Clear the screen
clear

echo -e "\e[36mGitHub Authentication Setup Script\e[0m"
echo -e "\e[36m=================================\e[0m"
echo "This script will help you fix Git authentication issues with GitHub."
echo "It will configure Git to use HTTPS with a personal access token."
echo ""

# Check if environment variables are already set
env_token="${FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"
env_owner="${FORK_AUTOGEN_OWNER}"
env_repo="${REPO_PATH:-autogen}"

use_env_vars=false
if [ -n "$env_token" ] && [ -n "$env_owner" ]; then
    echo -e "\e[32mFound environment variables for GitHub authentication.\e[0m"
    echo -e "\e[36mOwner: $env_owner\e[0m"
    read -p "Do you want to use these environment variables? (Y/n) " confirm_use_env
    if [ -z "$confirm_use_env" ] || [ "${confirm_use_env,,}" = "y" ]; then
        use_env_vars=true
        token="$env_token"
        owner="$env_owner"
        repo="$env_repo"
    fi
fi

if [ "$use_env_vars" = false ]; then
    # Get GitHub username
    if [ -n "$env_owner" ]; then
        read -p "Enter your GitHub username (default: $env_owner): " owner
        if [ -z "$owner" ]; then
            owner="$env_owner"
        fi
    else
        read -p "Enter your GitHub username (e.g., DeanLuus22021994): " owner
        while [ -z "$owner" ]; do
            echo -e "\e[31mGitHub username is required.\e[0m"
            read -p "Enter your GitHub username: " owner
        done
    fi

    # Get GitHub personal access token
    read -sp "Enter your GitHub Personal Access Token (PAT): " token
    echo ""

    while [ -z "$token" ]; do
        echo -e "\e[31mGitHub Personal Access Token is required.\e[0m"
        read -sp "Enter your GitHub Personal Access Token (PAT): " token
        echo ""
    done

    # Get repository name
    if [ -n "$env_repo" ]; then
        read -p "Enter the repository name (default: $env_repo): " repo
        if [ -z "$repo" ]; then
            repo="$env_repo"
        fi
    else
        read -p "Enter the repository name (default: autogen): " repo
        if [ -z "$repo" ]; then
            repo="autogen"
        fi
    fi
fi

# Configure Git credentials
configure_git_credentials "$token" "$owner"

# Test the connection
if test_github_connection "$token" "$owner" "$repo"; then
    connection_successful=true

    # Ask if user wants to permanently store these values as environment variables
    read -p "Do you want to store these values as environment variables for future use? (Y/n) " store_env_vars
    if [ -z "$store_env_vars" ] || [ "${store_env_vars,,}" = "y" ]; then
        # Determine shell profile file
        shell_profile=""
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

        # Set environment variables in shell profile
        for var_name in "FORK_AUTOGEN_OWNER" "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN" "REPO_PATH"; do
            var_value=""
            case "$var_name" in
                "FORK_AUTOGEN_OWNER") var_value="$owner" ;;
                "FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN") var_value="$token" ;;
                "REPO_PATH") var_value="$repo" ;;
            esac

            # Check if variable already exists
            if grep -q "export $var_name=" "$shell_profile"; then
                # Replace existing value
                sed -i.bak "s|export $var_name=.*|export $var_name=\"$var_value\"|g" "$shell_profile"
            else
                # Add new variable
                echo "export $var_name=\"$var_value\"" >> "$shell_profile"
            fi

            # Also set for current session
            export "$var_name"="$var_value"
        done

        echo -e "\e[32m✓ Environment variables have been saved to $shell_profile\e[0m"
        echo -e "\e[33mYou need to restart your terminal or run 'source $shell_profile' for the changes to take effect.\e[0m"
    fi

    # Offer to test the specific command that failed previously
    read -p "Do you want to test the 'git pull --tags origin DeanDev' command now? (Y/n) " test_specific_command
    if [ -z "$test_specific_command" ] || [ "${test_specific_command,,}" = "y" ]; then
        echo -e "\e[36mTesting 'git pull --tags origin DeanDev'...\e[0m"
        if git pull --tags origin DeanDev; then
            echo -e "\e[32m✓ Command executed successfully!\e[0m"
        else
            echo -e "\e[31m✗ Command failed. You may need additional configuration.\e[0m"
        fi
    fi
else
    echo -e "\e[31mAuthentication setup failed. Please check the following:\e[0m"
    echo -e "\e[33m1. Ensure your GitHub token has the correct permissions (repo, read:packages)\e[0m"
    echo -e "\e[33m2. Verify that your token has not expired\e[0m"
    echo -e "\e[33m3. Confirm that the repository exists and you have access to it\e[0m"
fi

echo ""
echo -e "\e[36mCurrent Git configuration:\e[0m"
git config --global --list | grep "url\."
