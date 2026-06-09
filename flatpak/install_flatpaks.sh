#!/usr/bin/env zsh

# Script to install Flatpaks in user mode from a file
# Usage: ./install_flatpaks.sh flatpak_apps.txt

echo "Starting Flatpak installation in user mode..."

# Check if file was provided
if [ $# -eq 0 ]; then
    echo "Error: Please provide the file with the list of Flatpaks."
    echo "Usage: $0 <file>"
    exit 1
fi

FILE="$1"

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found."
    exit 1
fi

# Check if Flatpak is installed
if ! command -v flatpak &> /dev/null; then
    echo "Error: Flatpak is not installed on the system."
    echo "Please install Flatpak first and configure the Flathub repository."
    exit 1
fi

# Add Flathub user repository if not configured
if ! flatpak remotes | grep flathub | grep user; then
    echo "Adding Flathub user repository..."
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

# Counters for statistics
total=0
installed=0
failures=0

echo "Reading Flatpaks from file: $FILE"
echo "=========================================="

# Read each line from the file
while IFS= read -r package; do
    # Skip empty lines
    if [[ -z "$package" || "$package" =~ ^[[:space:]]*$ ]]; then
        continue
    fi

    # Skip comment lines (optional)
    if [[ "$package" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    ((total++))

    echo "Installing: $package"

    # Try to install the Flatpak
    if flatpak install --user -y flathub "$package" 2>/dev/null; then
        echo "✓ Success: $package"
        ((installed++))
    else
        echo "✗ Failed: $package (not found on Flathub or installation error)"
        ((failures++))
    fi

    echo "------------------------------------------"

done < "$FILE"

# Display summary
echo "=========================================="
echo "INSTALLATION COMPLETED - SUMMARY:"
echo "Total packages in file: $total"
echo "Successfully installed packages: $installed"
echo "Failed packages: $failures"
echo "=========================================="

# Check if there are failed packages and suggest solution
if [ $failures -gt 0 ]; then
    echo ""
    echo "Some packages failed to install. Possible reasons:"
    echo "1. Incorrect package name"
    echo "2. Package not available on Flathub"
    echo "3. Need to add another repository"
    echo ""
    echo "You can manually check packages with:"
    echo "flatpak search <package-name>"
fi

