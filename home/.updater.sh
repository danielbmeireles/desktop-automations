#!/usr/bin/env zsh
# Author: Daniel Meireles <danielbmeireles@gmail.com>

set -euo pipefail

# Color functions
color_red() {
  echo -e "\033[31m${1}\033[0m"
}

color_green() {
  echo -e "\033[32m${1}\033[0m"
}

color_yellow() {
  echo -e "\033[33m${1}\033[0m"
}

color_blue() {
  echo -e "\033[34m${1}\033[0m"
}

# Prevent running with sudo
if [ "$(id -u)" -eq 0 ]; then
  color_red "Error: This script should not be run with sudo or as root."
  color_yellow "Please run it as a regular user: $0"
  exit 1
fi

# Detect distro flavors: ubuntu, fedora, opensuse-tumbleweed
DISTRO="unknown"
if [ -r /etc/os-release ]; then
  . /etc/os-release
  case "${ID:-}" in
    ubuntu)
      DISTRO="ubuntu"
      ;;
    fedora)
      DISTRO="fedora"
      ;;
    opensuse-tumbleweed)
      DISTRO="opensuse-tumbleweed"
      ;;
  esac
fi

# Function to run commands with elevation when needed
run_elev() {
  local cmd="$1"
  if [ "$(id -u)" -eq 0 ]; then
    sh -c "$cmd"
  else
    sudo sh -c "$cmd"
  fi
}

# Ask for sudo once and keep it alive, except on openSUSE Tumbleweed.
if [ "${DISTRO}" != "opensuse-tumbleweed" ] && [ "$(id -u)" -ne 0 ]; then
  if sudo -v; then
    # Keep-alive: update existing `sudo` time stamp until the script has finished
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    KEEPALIVE_PID=$!
  else
    color_yellow "sudo credential pre-check failed; continuing without keep-alive"
  fi
fi

color_blue "Detected distro: ${DISTRO}"

echo

# Step 1: System package upgrades (distro-specific)
color_yellow "Step 1: System package upgrades"
case "${DISTRO}" in
  ubuntu)
    run_elev "apt update && apt upgrade -y && apt autoremove -y && apt autoclean"
    ;;
  fedora)
    run_elev "dnf upgrade --refresh -y && dnf check && dnf autoremove -y"
    ;;
  opensuse-tumbleweed)
    run_elev "zypper refresh && zypper dup -y && zypper clean -a"
    ;;
  *)
    color_red "Unsupported distro: ${DISTRO}"
    exit 1
    ;;
esac
color_green "System packages upgraded (or attempted)."

echo

# Step 2: Flatpak updates (system + user))
if command -v flatpak >/dev/null 2>&1; then
  color_yellow "Step 2: Flatpak updates"

  # Update system flatpaks
  color_yellow "Updating system flatpaks (requires elevation)"
  run_elev "flatpak update --system -y"

  # Update user flatpaks
  color_yellow "Updating user flatpaks"
  flatpak update -y

  # Remove unused system flatpaks after updates
  color_yellow "Removing unused system flatpaks (requires elevation)"
  run_elev "flatpak uninstall --system --unused -y"

  # Remove unused user flatpaks after updates
  color_yellow "Removing unused user flatpaks"
  flatpak uninstall --unused -y

  color_green "Flatpaks updated and cleaned up!"
else
  color_yellow "Flatpak not installed: skipping flatpak updates"
fi

echo

# Step 3: Brew upgrades
if command -v brew >/dev/null 2>&1; then
  color_yellow "Step 3: Homebrew upgrades"
  brew update && brew upgrade -y && brew cleanup
  color_green "Homebrew packages upgraded!"
else
  color_yellow "Homebrew not installed: skipping brew updates"
fi

echo

# Step 4: Firmware updates (fwupdmgr)
if command -v fwupdmgr >/dev/null 2>&1; then
  color_red "Step 4: Firmware updates"
  run_elev "fwupdmgr get-devices"
  run_elev "fwupdmgr refresh --force"
  run_elev "fwupdmgr get-updates"
  run_elev "fwupdmgr update"
  color_green "Firmwares updated (or checked)."
else
  color_yellow "fwupdmgr not found: skipping firmware updates"
fi

echo

# Cleanup: stop keepalive loop if started
if [ -n "${KEEPALIVE_PID:-}" ] 2>/dev/null; then
  kill "${KEEPALIVE_PID}" 2>/dev/null
fi

color_green "All done!"
