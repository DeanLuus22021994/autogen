#!/bin/bash

# Quick fix for Git SSH authentication issues
# This script configures Git to use HTTPS with a personal access token for GitHub

# Set default values (no user input required)
owner="DeanLuus22021994"
repo="autogen"
token="${FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN}"

# Check if token is available
if [ -z "$token" ]; then
    echo -e "\e[31mNo personal access token found in environment variables.\e[0m"
    echo -e "\e[33mUsing a placeholder token for demonstration. This will not work with real repositories.\e[0m"
    token="PLACEHOLDER_TOKEN"
fi

# Configure Git to use HTTPS with personal access token
echo -e "\e[36mConfiguring Git to use HTTPS with personal access token...\e[0m"
git config --global url."https://$token@github.com/$owner".insteadOf "git@github.com:$owner"
git config --global url."https://$token@github.com/$owner".insteadOf "https://github.com/$owner"

echo -e "\e[32mGit configured to use HTTPS with personal access token for $owner repositories\e[0m"

# Show current Git configuration
echo ""
echo -e "\e[36mCurrent Git URL configuration:\e[0m"
git config --global --list | grep "url\."

# Instructions for re-running the specific Git command
echo ""
echo -e "\e[36mYou can now retry your Git command:\e[0m"
echo -e "\e[33mgit pull --tags origin DeanDev\e[0m"

# Additional instructions for properly setting up the token
if [ -z "$FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN" ]; then
    echo ""
    echo -e "\e[36mTo make this work permanently, set the FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN environment variable:\e[0m"
    echo -e "\e[33mexport FORK_AUTOGEN_USER_PERSONAL_ACCESS_TOKEN='your-github-pat'\e[0m"
fi
