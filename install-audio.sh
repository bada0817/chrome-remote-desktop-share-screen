#!/bin/bash
# Optional: forward desktop audio to the Chrome Remote Desktop client.
# Run as your normal user (no sudo): bash install-audio.sh
# Uninstall: bash install-audio.sh --uninstall
set -euo pipefail

[ "$(id -u)" -ne 0 ] || { echo "Run without sudo"; exit 1; }
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin/crd-audio-tunnel"
UNIT="$HOME/.config/systemd/user/crd-audio-tunnel.service"

if [ "${1:-}" = "--uninstall" ]; then
  systemctl --user disable --now crd-audio-tunnel.service 2>/dev/null || true
  pactl list short modules | awk '$2 == "module-tunnel-sink" && /sink_name=crd_remote/ {print $1}' \
    | xargs -r -n1 pactl unload-module
  rm -f "$BIN" "$UNIT"
  systemctl --user daemon-reload
  echo "Removed. Pick your normal output device in Settings > Sound."
  exit 0
fi

command -v pactl >/dev/null || { echo "pactl not found (install pulseaudio-utils)"; exit 1; }
install -Dm755 "$DIR/audio/crd-audio-tunnel" "$BIN"
install -Dm644 "$DIR/audio/crd-audio-tunnel.service" "$UNIT"
systemctl --user daemon-reload
systemctl --user enable --now crd-audio-tunnel.service

echo "Done. While connected, choose \"Chrome Remote Desktop\" in Settings > Sound > Output."
echo "Switch back to your speakers when using the computer locally."
