#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    printf "${!1}%s${NC}\n" "$2"
}

# Function to ask for overwrite confirmation
ask_overwrite() {
    local item="$1"
    read -p "Do you want to override the existing $item? (y/n): " answer
    [[ $answer == [Yy]* ]]
}

# Kill any running instances of nlogout
print_color "YELLOW" "Terminating any running nlogout instances..."
pkill -f "nlogout" || true  # Don't exit if no process found

# # Install nim language
# print_color "YELLOW" "Installing nim..."
# if sudo pacman -S nim --noconfirm --needed; then
#     print_color "GREEN" "nim installed successfully."
# else
#     print_color "RED" "Failed to install nim. Please install it manually and rerun this script."
#     exit 1
# fi

# # Install required Nim modules
# print_color "YELLOW" "Installing required Nim modules..."
# if yes | nimble install parsetoml && yes | nimble install nigui; then
#     print_color "GREEN" "Modules installed successfully."
# else
#     print_color "RED" "Failed to install required modules. Please check your internet connection and try again."
#     exit 1
# fi

# Create output directory
mkdir -p "$HOME/.config/nlogout"

# Compile nlogout
print_color "YELLOW" "Compiling nlogout..."
if nim compile --define:release --opt:size --app:gui --outdir="$HOME/.config/nlogout/" src/nlogout.nim; then
    print_color "GREEN" "nlogout compiled successfully."
else
    print_color "RED" "Failed to compile nlogout. Please check the error messages above."
    exit 1
fi

# Copy config.toml with user prompt for overwrite
if [[ -e $HOME/.config/nlogout/config.toml ]]; then
    print_color "YELLOW" "config.toml already exists."
    if ask_overwrite "config.toml"; then
        if cp config.toml "$HOME/.config/nlogout/config.toml"; then
            print_color "GREEN" "config.toml has been overwritten."
        else
            print_color "RED" "Failed to overwrite config.toml. Please check file permissions."
            exit 1
        fi
    else
        print_color "YELLOW" "Keeping existing config.toml."
    fi
else
    print_color "YELLOW" "Copying config.toml..."
    if cp config.toml "$HOME/.config/nlogout/config.toml"; then
        print_color "GREEN" "config.toml copied successfully."
    else
        print_color "RED" "Failed to copy config.toml. Please check file permissions."
        exit 1
    fi
fi

# Copy themes with user prompt for overwrite
if [[ -e $HOME/.config/nlogout/themes ]]; then
    print_color "YELLOW" "Themes directory already exists."
    if ask_overwrite "themes"; then
        print_color "YELLOW" "Copying themes..."
        if rm -rf "$HOME/.config/nlogout/themes" && cp -r ./themes "$HOME/.config/nlogout/themes"; then
            print_color "GREEN" "Themes have been overwritten."
        else
            print_color "RED" "Failed to overwrite themes. Please check directory permissions."
            exit 1
        fi
    else
        print_color "YELLOW" "Keeping existing themes."
    fi
else
    print_color "YELLOW" "Copying themes..."
    if cp -r ./themes "$HOME/.config/nlogout/themes"; then
        print_color "GREEN" "Themes copied successfully."
    else
        print_color "RED" "Failed to copy themes. Please check directory permissions."
        exit 1
    fi
fi

print_color "GREEN" "nlogout setup completed successfully."