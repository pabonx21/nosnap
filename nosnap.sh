#!/bin/bash

# set -e

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be executed as root (use sudo)."
   exit 1
fi

echo "--- Starting Snap purge ---"

# 1. Stop the service to avoid locks
systemctl stop snapd.service snapd.socket

# 2. Uninstall all installed snaps individually
# This is done in a loop because some depend on others
echo "Removing installed snaps..."
while [ "$(snap list | wc -l)" -gt 0 ]; do
    for s in $(snap list | awk 'NR>1 {print $1}'); do
        snap remove --purge "$s"
    done
    # If only the 'no snaps installed' error remains, we exit
    if snap list 2>&1 | grep -q "no snaps installed"; then break; fi
done

# 3. Unmount snap mount points if residues remain
echo "Unmounting snap units..."
umount -fl /var/lib/snapd/snaps/* 2>/dev/null

# 4. Remove the core and the daemon
echo "Removing snapd and tools..."
apt purge -y snapd gnome-software-plugin-snap

# 5. Cleanup of residual directories
echo "Cleaning directories..."
rm -rf /var/lib/snapd
rm -rf /var/cache/snapd
rm -rf /root/snap
rm -rf /home/*/snap

# 6. BLACKLIST: Prevent automatic reinstallation
echo "Creating preference rule to block snapd..."
cat <<EOF > /etc/apt/preferences.d/nosnap.pref
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

echo "--- Process completed. Ubuntu is Snap-free. ---"
