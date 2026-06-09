#!/usr/bin/env zsh
# others_install.sh — Deploy backup configuration files to their system locations
# Must be run as root (or via sudo)

set -euo pipefail

# ---------------------------------------------------------------------------
# Root check
# ---------------------------------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root. Use: sudo bash $0" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 1. /etc/systemd/system/backup-extdrive.service  (644 root:root)
# ---------------------------------------------------------------------------
cat > /etc/systemd/system/backup-extdrive.service << 'EOF'
[Unit]
Description=Backup service for external drive
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup_wrapper.sh
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF

chown root:root /etc/systemd/system/backup-extdrive.service
chmod 644 /etc/systemd/system/backup-extdrive.service
echo "Installed: /etc/systemd/system/backup-extdrive.service (owner=root:root, mode=644)"

# Reload systemd so the new unit is recognised
systemctl daemon-reload
echo "systemd daemon reloaded"

# ---------------------------------------------------------------------------
# 2. /etc/udev/rules.d/99-backup-extdrive.rules  (644 root:root)
# ---------------------------------------------------------------------------
cat > /etc/udev/rules.d/99-backup-extdrive.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="fc13c291-6624-4ce8-9f3f-2cab94d405f8", ENV{SYSTEMD_WANTS}="backup-extdrive.service", TAG+="systemd"
EOF

chown root:root /etc/udev/rules.d/99-backup-extdrive.rules
chmod 644 /etc/udev/rules.d/99-backup-extdrive.rules
echo "Installed: /etc/udev/rules.d/99-backup-extdrive.rules (owner=root:root, mode=644)"

# Reload udev rules so the new rule takes effect immediately
udevadm control --reload-rules
echo "udev rules reloaded"

# ---------------------------------------------------------------------------
# 3. /usr/local/bin/backup_wrapper.sh  (755 root:root)
# ---------------------------------------------------------------------------
cat > /usr/local/bin/backup_wrapper.sh << 'EOF'
#!/usr/bin/env zsh

# Wrapper script for udev execution

# Log execution attempt
echo "$(date): Backup triggered" >> /var/log/backup_attempts.log

# Wait for the drive to be properly mounted
sleep 10

# Execute the actual backup script as your user
su - daniel -c "/home/daniel/.backup.sh" >> /var/log/backup_attempts.log 2>&1

exit 0
EOF

chown root:root /usr/local/bin/backup_wrapper.sh
chmod 755 /usr/local/bin/backup_wrapper.sh
echo "Installed: /usr/local/bin/backup_wrapper.sh (owner=root:root, mode=755)"

echo ""
echo "All files installed successfully."
