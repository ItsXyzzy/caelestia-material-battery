#!/usr/bin/env bash
#
# Caelestia battery popout: uninstaller
#
# Restores the Battery.qml the installer backed up.
#
# Usage: ./uninstall.sh
#
set -euo pipefail

XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET="$XDG_CONFIG/quickshell/caelestia"
BATTERY="$TARGET/modules/bar/popouts/Battery.qml"

if [ "$EUID" -eq 0 ]; then
    echo "Don't run this with sudo. It works on your user config."
    exit 1
fi

if [ ! -d "$TARGET" ]; then
    echo "Nothing to uninstall: $TARGET doesn't exist."
    exit 0
fi

if [ -f "$BATTERY.bak" ]; then
    mv "$BATTERY.bak" "$BATTERY"
    echo "Restored the original Battery.qml."
else
    echo "No backup found, so there's nothing to restore."
fi

echo
echo "Restart the shell."
echo "Your user copy at $TARGET still overrides /etc/xdg/quickshell/caelestia."
echo "To let package updates apply again, delete it: rm -rf \"$TARGET\""
