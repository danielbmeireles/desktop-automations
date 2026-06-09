#!/usr/bin/env zsh
# install.sh — Install user systemd units into ~/.config/systemd/user

if [[ "$EUID" -eq 0 ]]; then
    echo "ERROR: Do not run with sudo. Run as your user: bash install.sh" >&2
    exit 1
fi

PROTONVPN_COUNTRIES=()
RCLONE_SERVICES=()

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --dropbox)   RCLONE_SERVICES+=("Dropbox") ;;
        --onedrive)  RCLONE_SERVICES+=("OneDrive") ;;
        --gdrive)    RCLONE_SERVICES+=("GoogleDrive") ;;
        [A-Za-z][A-Za-z])
            PROTONVPN_COUNTRIES+=("$(printf '%s' "$arg" | tr '[:upper:]' '[:lower:]')")
            ;;
        *)
            echo "Unknown flag: $arg" >&2
            exit 1
            ;;
    esac
done

TARGET_DIR="$HOME/.config/systemd/user"
mkdir -p "$TARGET_DIR"

cd "$(dirname "$0")"
cp protonvpn@.service rclone@.service "$TARGET_DIR/"
echo "Installed units to $TARGET_DIR"

systemctl --user daemon-reload
echo "Reloaded user systemd daemon"

echo ""
if [[ ${#PROTONVPN_COUNTRIES[@]} -gt 0 ]]; then
    echo "Configured ProtonVPN instances:"
    for country in "${PROTONVPN_COUNTRIES[@]}"; do
        echo "  protonvpn@$country.service"
    done
    echo ""
    echo "Start one when needed, for example:"
    echo "  systemctl --user start protonvpn@${PROTONVPN_COUNTRIES[0]}.service"
fi

if [[ ${#RCLONE_SERVICES[@]} -gt 0 ]]; then
    echo "Enabling rclone services:"
    for service in "${RCLONE_SERVICES[@]}"; do
        systemctl --user enable --now rclone@"$service".service
        echo "  ✓ rclone@$service"
    done
fi

if [[ ${#PROTONVPN_COUNTRIES[@]} -eq 0 && ${#RCLONE_SERVICES[@]} -eq 0 ]]; then
    echo "Usage:"
    echo "  bash install.sh PT US BR --dropbox --onedrive --gdrive"
    echo ""
    echo "Rclone flags:"
    echo "  --dropbox    Enable rclone@Dropbox.service"
    echo "  --onedrive   Enable rclone@OneDrive.service"
    echo "  --gdrive     Enable rclone@GoogleDrive.service"
    echo ""
    echo "ProtonVPN country codes:"
    echo "  Any 2-letter code configures protonvpn@xx.service"
    echo "  Examples: PT -> protonvpn@pt.service, US -> protonvpn@us.service"
fi
