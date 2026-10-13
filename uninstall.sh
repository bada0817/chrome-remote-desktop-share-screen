#!/bin/bash
# Restore the original Chrome Remote Desktop script and remove the apt hook.
# Run: sudo bash uninstall.sh   (Chrome Remote Desktop itself stays installed)
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo"; exit 1; }
USER_NAME="${SUDO_USER:?Run with sudo from your normal user account}"
SCRIPT=/opt/google/chrome-remote-desktop/chrome-remote-desktop

rm -f /usr/local/sbin/crd-share-screen-patch /etc/apt/apt.conf.d/99crd-share-screen-patch

if [ -f "$SCRIPT.orig" ]; then
  mv "$SCRIPT.orig" "$SCRIPT"
  echo "Restored $SCRIPT"
else
  echo "No backup found; reinstall the package to restore: apt-get install --reinstall chrome-remote-desktop"
fi

if systemctl is-enabled --quiet "chrome-remote-desktop@$USER_NAME" 2>/dev/null; then
  systemctl restart "chrome-remote-desktop@$USER_NAME"
fi
