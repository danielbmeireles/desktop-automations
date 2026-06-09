#!/usr/bin/env zsh

set -euo pipefail

# Timestamp
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Get hostname
HOSTNAME=$(hostname)

# Configuration
BACKUP_BASE_DIR="/run/media/daniel/Backup"
BACKUP_DIR="$BACKUP_BASE_DIR/$HOSTNAME"
HOME_DIR="$HOME"

# Check if backup drive is mounted
if [ ! -d "$BACKUP_BASE_DIR" ]; then
    echo "Backup drive not mounted at $BACKUP_BASE_DIR. Exiting."
    exit 1
fi

# Create host-specific directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Creating backup directory for host: $HOSTNAME"
    mkdir -p "$BACKUP_DIR"
fi

LOG_FILE="$BACKUP_DIR/backup.$TIMESTAMP.log"

# Basic helpers
log() { echo "$(date +"%Y-%m-%d %H:%M:%S") - $*" | tee -a "$LOG_FILE"; }

log "Backup started"

# Backup home directory (excluding large/unnecessary folders)
log "Backing up home directory..."
mkdir -p "$BACKUP_DIR/home"
rsync -aAXv \
    --exclude=".cache" \
    --exclude=".ccache" \
    --exclude=".config/*/Cache" \
    --exclude=".config/*/Code Cache" \
    --exclude=".gvfs" \
    --exclude=".local/share/containers" \
    --exclude=".local/share/Trash" \
    --exclude=".Private" \
    --exclude=".snap/*/*/.cache" \
    --exclude=".snap/*/*/.config/Cache" \
    --exclude=".snap/*/*/.config/Code Cache" \
    --exclude=".steam/root" \
    --exclude=".var/app/*/cache" \
    --exclude=".var/app/*/config/Cache" \
    --exclude=".var/app/*/config/Code Cache" \
    --exclude=".var/app/com.valvesoftware.Steam/.steam/root" \
    --exclude="maestral-venv" \
    --exclude="rclone" \
    "$HOME_DIR/" "$BACKUP_DIR/home/" >> "$LOG_FILE" 2>&1 || log "Warning: rsync /home returned non-zero exit code"

log "Home directory backup finished"

# Backup important system configurations
log "Backing up /etc (requires sudo)..."
mkdir -p "$BACKUP_DIR/etc"
sudo rsync -aAX --ignore-errors \
    --exclude="mtab" \
    --exclude="resolv.conf" \
    /etc/ "$BACKUP_DIR/etc/" >> "$LOG_FILE" 2>&1 || log "Warning: rsync /etc returned non-zero exit code"
log "/etc backup finished"

# Detect distro: ubuntu, fedora, opensuse-tumbleweed
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
log "Detected distro: $DISTRO"

# Backup list of installed packages (distro-specific)
log "Backing up package lists..."
mkdir -p "$BACKUP_DIR/packages"
case "$DISTRO" in
    ubuntu)
        log "Using Debian/Ubuntu package list commands"
        dpkg --get-selections > "$BACKUP_DIR/packages/dpkg_selections.txt" 2>>"$LOG_FILE" || true
        apt list --installed > "$BACKUP_DIR/packages/apt_installed.txt" 2>>"$LOG_FILE" || true
        apt-mark showmanual > "$BACKUP_DIR/packages/apt_manual.txt" 2>>"$LOG_FILE" || true
        ;;
    fedora)
        log "Using DNF/RPM package list commands"
        if command -v dnf >/dev/null 2>&1; then
            dnf list --installed > "$BACKUP_DIR/packages/dnf_installed.txt" 2>>"$LOG_FILE" || true
            # repoquery may not be available; try and ignore errors
            if command -v repoquery >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
                dnf repoquery --userinstalled > "$BACKUP_DIR/packages/dnf_userinstalled.txt" 2>>"$LOG_FILE" || true
            fi
        fi
        rpm -qa > "$BACKUP_DIR/packages/rpm_qa.txt" 2>>"$LOG_FILE" || true
        ;;
    opensuse-tumbleweed)
        log "Using zypper/RPM package list commands"
        if command -v zypper >/dev/null 2>&1; then
            zypper se --installed-only > "$BACKUP_DIR/packages/zypper_installed.txt" 2>>"$LOG_FILE" || true
        fi
        rpm -qa > "$BACKUP_DIR/packages/rpm_qa.txt" 2>>"$LOG_FILE" || true
        ;;
    *)
        log "Unsupported distro: $DISTRO; skipping package list backup"
        ;;
esac
log "Package lists saved to $BACKUP_DIR/packages"

# Backup Flatpak applications (user and system) if flatpak is installed
if command -v flatpak >/dev/null 2>&1; then
    log "Backing up Flatpak applications"
    mkdir -p "$BACKUP_DIR/flatpak"
    flatpak --user list --app --columns=application > "$BACKUP_DIR/flatpak/flatpak_user_apps.txt" 2>>"$LOG_FILE" \
        || log "Warning: failed to list user Flatpak apps"
    flatpak --system list --app --columns=application > "$BACKUP_DIR/flatpak/flatpak_system_apps.txt" 2>>"$LOG_FILE" \
        || log "Warning: failed to list system Flatpak apps"
else
    log "Flatpak not installed; skipping"
fi

# Backup Homebrew package lists if brew is installed
if command -v brew >/dev/null 2>&1; then
    log "Backing up Homebrew packages..."
    mkdir -p "$BACKUP_DIR/brew"
    brew bundle dump --file "$BACKUP_DIR/brew/Brewfile" --force >> "$LOG_FILE" 2>&1 \
        || log "Warning: brew bundle dump failed"
else
    log "Homebrew not installed; skipping"
fi

log ""
log "══════════════════════════════════════"
log "  Backup completed"
log "  Finished  : $(date +"%Y-%m-%d %H:%M:%S")"
log "  Location  : $BACKUP_DIR"
log "  Log file  : $LOG_FILE"
log "══════════════════════════════════════"

exit 0
