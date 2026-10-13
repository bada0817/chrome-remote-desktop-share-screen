#!/bin/bash
# Install Chrome Remote Desktop and patch it to share the current screen (:0).
# Run from your normal user account: sudo bash install.sh
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo"; exit 1; }
USER_NAME="${SUDO_USER:?Run with sudo from your normal user account}"
DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_BIN=/usr/local/sbin/crd-share-screen-patch
APT_HOOK=/etc/apt/apt.conf.d/99crd-share-screen-patch

# Warn if the graphical session is not Xorg (the patch needs X11).
for s in $(loginctl list-sessions --no-legend | awk -v u="$USER_NAME" '$3 == u {print $1}'); do
  type="$(loginctl show-session "$s" -p Type --value)"
  if [ "$type" = "wayland" ]; then
    echo "WARNING: $USER_NAME is in a Wayland session. Log in with an Xorg session"
    echo "         (e.g. 'Ubuntu on Xorg') or this patch will not work."
  fi
done

# 1. Install or update the package
TMP="$(mktemp -d)"
curl -fLo "$TMP/crd.deb" https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
apt-get install -y "$TMP/crd.deb"
rm -rf "$TMP"

# 2. Group membership (newer packages no longer create this group)
if getent group chrome-remote-desktop >/dev/null; then
  usermod -aG chrome-remote-desktop "$USER_NAME"
fi

# 3. Patch (root-owned copy so the apt hook never runs a user-writable file)
install -m 755 -o root -g root "$DIR/patch-crd.py" "$PATCH_BIN"
"$PATCH_BIN"

# 4. Re-apply the patch automatically after package updates
cat > "$APT_HOOK" <<EOF
DPkg::Post-Invoke { "[ -x $PATCH_BIN ] && $PATCH_BIN >/dev/null 2>&1 || true"; };
EOF

# 5. Restart the host if it is already registered
if systemctl is-enabled --quiet "chrome-remote-desktop@$USER_NAME" 2>/dev/null; then
  systemctl restart "chrome-remote-desktop@$USER_NAME"
  echo "Restarted chrome-remote-desktop@$USER_NAME."
fi

echo
echo "Done."
echo "If this computer is not registered yet: open https://remotedesktop.google.com/headless"
echo "(any browser), copy the Debian Linux command, and run it as $USER_NAME (NOT with sudo)."
