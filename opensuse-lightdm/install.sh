#!/usr/bin/env zsh
# install.sh — Deploy LightDM configuration files to their system locations

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root. Use: sudo bash $0" >&2
    exit 1
fi

mkdir -p /usr/share/lightdm/lightdm.conf.d

cat > /usr/share/fix_resolution.sh << 'EOF'
#!/bin/sh

# Detect connected monitors
external=$(xrandr | grep -E "^(DP|HDMI|VGA)-[0-9]+ connected" | head -1 | cut -d" " -f1)

if [ -n "$external" ]; then
    # External monitor present: force a specific resolution
    xrandr --output eDP-1 --auto --primary \
          --output "$external" --mode 1920x1080 --left-of eDP-1
else
    # Internal screen only
    xrandr --output eDP-1 --auto --primary
fi

exit 0
EOF

chown root:root /usr/share/fix_resolution.sh
chmod 755 /usr/share/fix_resolution.sh
echo "Installed: /usr/share/fix_resolution.sh (owner=root:root, mode=755)"

if [[ -f /usr/share/lightdm/lightdm.conf.d/50-suse-defaults.conf ]]; then
    backup_file="/usr/share/lightdm/lightdm.conf.d/50-suse-defaults.conf.bak.$(date +%Y%m%d%H%M%S)"
    cp -p /usr/share/lightdm/lightdm.conf.d/50-suse-defaults.conf "$backup_file"
    echo "Backup created: $backup_file"
fi

cat > /usr/share/lightdm/lightdm.conf.d/50-suse-defaults.conf << 'EOF'
[Seat:*]
pam-service = lightdm
pam-autologin-service = lightdm-autologin
pam-greeter-service = lightdm-greeter
xserver-command=/usr/bin/X
session-wrapper=/usr/etc/X11/xdm/Xsession
greeter-setup-script=/usr/etc/X11/xdm/Xsetup
session-setup-script=/usr/etc/X11/xdm/Xstartup
session-cleanup-script=/usr/etc/X11/xdm/Xreset
display-setup-script=/usr/share/fix_resolution.sh
EOF

chown root:root /usr/share/lightdm/lightdm.conf.d/50-suse-defaults.conf
chmod 644 /usr/share/lightdm/lightdm.conf.d/50-suse-defaults.conf
echo "Installed: /usr/share/lightdm/lightdm.conf.d/50-suse-defaults.conf (owner=root:root, mode=644)"

echo ""
echo "All files installed successfully."
