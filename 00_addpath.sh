#!/bin/bash
# A script to add this directory to appropriate shell configuration file

# 13 Dec 2024 K. Nemoto

# Detect OS using uname
OS=$(uname -s)

case $OS in
    "Linux")
        CONFIG_FILE="$HOME/.bash_aliases"
        ;;
    "Darwin")  # macOS
        # Detect current shell
        CURRENT_SHELL=$(basename "$SHELL")
        
        case $CURRENT_SHELL in
            "zsh")
                CONFIG_FILE="$HOME/.zprofile"
                ;;
            "bash")
                CONFIG_FILE="$HOME/.bash_profile"
                ;;
            *)
                echo "Unsupported shell: $CURRENT_SHELL"
                echo "Please manually add this directory to your shell configuration."
                exit 1
                ;;
        esac
        ;;
    *)
        echo "Unsupported operating system: $OS"
        echo "This script supports only Linux and macOS."
        exit 1
        ;;
esac

# Check if PATH already exists in config file
grep '# PATH for batch_heudiconv' "$CONFIG_FILE" > /dev/null
if [ $? -eq 1 ]; then
    echo >> "$CONFIG_FILE"
    echo '# PATH for batch_heudiconv' >> "$CONFIG_FILE"
    echo "export PATH=\$PATH:$PWD" >> "$CONFIG_FILE"
    echo "PATH for batch_heudiconv was added to $CONFIG_FILE"
    echo "Please restart your terminal or run: source $CONFIG_FILE"
else
    echo "PATH for batch_heudiconv already exists in $CONFIG_FILE"
fi
