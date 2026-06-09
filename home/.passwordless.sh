#!/usr/bin/env zsh

# Check if the script is run with sudo privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please use sudo."
   exit 1
fi

# Get the username of the person who invoked sudo
USER=$SUDO_USER

# Add a no-password rule for the user in sudoers
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER >/dev/null

# Set the appropriate permissions on the file
sudo chmod 440 /etc/sudoers.d/$USER

echo "Passwordless sudo is now enabled for the user $USER."
