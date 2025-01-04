#!/bin/sh

set -e # Stop the script if any command fails

# Function to check if a command is available
check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR" "$1 is not installed or available." >&2
    exit 1
  fi
}

echo "INFO" "Updating packages and installing git..."
apk update && apk add --no-cache git

echo "INFO" "Cloning the dotfiles repository..."
repo_url="https://github.com/matteocavestri/nscdots.git"
git clone "$repo_url"

# Check if the repository was cloned successfully
if [ ! -d "nscdots" ]; then
  echo "ERROR" "Failed to clone the repository." >&2
  exit 1
fi

# Scripts to be executed
scripts_dir="./nscdots/usr"
hardware_script="$scripts_dir/sbin/setup-hardware"
desktop_env_script="$scripts_dir/sbin/setup-desktop-environment"
install_nscdots_script="$scripts_dir/bin/install-nscdots"
install_home_script="$scripts_dir/bin/install-home"

echo "INFO" "Running the setup-hardware script..."
check_command sh
sh "$hardware_script"

echo "INFO" "Running the setup-desktop-environment script..."
sh "$desktop_env_script"

echo "INFO" "Running the install-nscdots script..."
sh "$install_nscdots_script"

echo "INFO" "Running the install-home script..."
sh "$install_home_script"

echo "INFO" "Installation completed successfully!"
