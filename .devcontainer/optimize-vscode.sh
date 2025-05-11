#!/bin/bash
echo "Optimizing VS Code Server performance..."
if [ -d /root/.vscode-server ]; then
    find /root/.vscode-server -name "*.js" -type f -exec touch {} \;
    find /root/.vscode-server -name "*.json" -type f -exec touch {} \;
fi
