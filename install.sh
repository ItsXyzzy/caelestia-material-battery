#!/usr/bin/env bash
#
# Caelestia battery popout: installer
#
# Installs into your user config (~/.config/quickshell/caelestia). No sudo needed,
# and package updates won't overwrite it.
#
# Usage: ./install.sh [--time-style left|until] [--clock auto|12|24]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="${CAELESTIA_SYSTEM_DIR:-/etc/xdg/quickshell/caelestia}"
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET="$XDG_CONFIG/quickshell/caelestia"
SRC="$SCRIPT_DIR/qml/modules/bar/popouts/Battery.qml"
BATTERY="$TARGET/modules/bar/popouts/Battery.qml"

TIME_STYLE=""
CLOCK=""

usage() {
    cat <<'EOF'
Usage: ./install.sh [--time-style left|until] [--clock auto|12|24]

  --time-style   "left" shows "6h 29m left", "until" shows "until 22:30"
  --clock        Clock format for "until": follow the shell (auto), 12-hour or 24-hour

Without options it asks, when run in a terminal. Run it again any time to change them.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --time-style|--clock)
            [ $# -ge 2 ] || { echo "$1 needs a value."; exit 1; }
            case "$1" in --time-style) TIME_STYLE="$2" ;; --clock) CLOCK="$2" ;; esac
            shift 2 ;;
        --time-style=*) TIME_STYLE="${1#*=}"; shift ;;
        --clock=*)      CLOCK="${1#*=}"; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

case "$TIME_STYLE" in ""|left|until) ;; *) echo "--time-style must be 'left' or 'until'."; exit 1 ;; esac
case "$CLOCK" in ""|auto|12|24) ;; *) echo "--clock must be 'auto', '12' or '24'."; exit 1 ;; esac

if [ "$EUID" -eq 0 ]; then
    echo "Don't run this with sudo. It installs into your user config."
    exit 1
fi

# Check everything before writing anything.
if [ -d "$TARGET" ]; then ROOT="$TARGET"; else ROOT="$SYSTEM_DIR"; fi
STOCK="$ROOT/modules/bar/popouts/Battery.qml"

if [ ! -f "$STOCK" ]; then
    echo "Couldn't find Caelestia's battery popout at $STOCK."
    echo "Install caelestia-shell first, or set CAELESTIA_SYSTEM_DIR."
    exit 1
fi

missing=()
grep -q "batteryWidth" "$STOCK" || missing+=("a battery popout sized by Tokens.sizes.bar.batteryWidth")
grep -rqs "Caelestia.I18n" "$ROOT/modules" "$ROOT/services" || missing+=("the Caelestia.I18n module")
grep -qs "percentOne" "$ROOT/utils/Strings.qml" || missing+=("Strings.percentOne")
[ -f "$ROOT/components/StyledClippingRect.qml" ] || missing+=("components/StyledClippingRect.qml")
if [ "${#missing[@]}" -gt 0 ]; then
    echo "This popout needs a newer Caelestia. Missing:"
    printf '  - %s\n' "${missing[@]}"
    echo "Nothing was changed."
    exit 1
fi

# Ask when run in a terminal, otherwise use the defaults.
if [ -z "$TIME_STYLE" ] && [ -t 0 ]; then
    echo
    echo "How should the time be shown?"
    echo "  1) Time left, like '6h 29m left'  (default)"
    echo "  2) Time until, like 'until 22:30'"
    read -rp "Choose [1/2]: " reply || reply=""
    case "$reply" in 2) TIME_STYLE=until ;; *) TIME_STYLE=left ;; esac
fi
TIME_STYLE="${TIME_STYLE:-left}"

if [ "$TIME_STYLE" = "until" ] && [ -z "$CLOCK" ] && [ -t 0 ]; then
    echo
    echo "Clock format for the 'until' time:"
    echo "  1) Follow my shell's setting  (default)"
    echo "  2) 12-hour, like '9:30 PM'"
    echo "  3) 24-hour, like '21:30'"
    read -rp "Choose [1/2/3]: " reply || reply=""
    case "$reply" in 2) CLOCK=12 ;; 3) CLOCK=24 ;; *) CLOCK=auto ;; esac
fi
CLOCK="${CLOCK:-auto}"

echo
echo "Installing the battery popout..."

# A user copy takes priority over /etc/xdg and survives package updates.
if [ ! -d "$TARGET" ]; then
    echo "-> Copying $SYSTEM_DIR to $TARGET"
    mkdir -p "$XDG_CONFIG/quickshell"
    cp -r "$SYSTEM_DIR" "$TARGET"
fi

# Only the first backup is kept, so running the installer twice never overwrites the original.
if [ ! -f "$BATTERY.bak" ]; then
    cp "$BATTERY" "$BATTERY.bak"
fi
cp "$SRC" "$BATTERY"

if [ "$TIME_STYLE" = "until" ]; then use_clock=true; else use_clock=false; fi
sed -i -e "s/readonly property bool useClockTime: [a-z]*/readonly property bool useClockTime: $use_clock/" \
       -e "s/readonly property string clockFormat: \"[a-z0-9]*\"/readonly property string clockFormat: \"$CLOCK\"/" "$BATTERY"

if grep -q "useClockTime: $use_clock" "$BATTERY" && grep -q "clockFormat: \"$CLOCK\"" "$BATTERY"; then
    echo "  ok:   Battery.qml (time $TIME_STYLE, clock $CLOCK)"
else
    echo "  warn: couldn't apply the time options. Edit useClockTime and clockFormat at the top of Battery.qml." >&2
fi

echo
echo "Done. Restart the shell (log out and back in, or stop it and run 'caelestia shell')."
echo "To change the time options, run ./install.sh again. To undo: ./uninstall.sh"
