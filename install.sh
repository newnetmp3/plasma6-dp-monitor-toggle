#!/usr/bin/env bash
set -euo pipefail

ID="com.scott.dp23toggle"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE="$HERE/package"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "Error: kpackagetool6 is not installed."
    echo "On Arch Linux it is provided by KDE Frameworks packages."
    exit 1
fi

if ! command -v kscreen-doctor >/dev/null 2>&1; then
    echo "Error: kscreen-doctor is not installed."
    exit 1
fi

echo "Installing $ID..."
kpackagetool6 --type Plasma/Applet --remove "$ID" >/dev/null 2>&1 || true
kpackagetool6 --type Plasma/Applet --install "$PACKAGE"

echo
echo "Installed."
echo "Add it with: right-click the Plasma panel -> Add Widgets -> search for:"
echo "  DP-2 + DP-3 Toggle"
echo
echo "If it does not appear immediately, run:"
echo "  systemctl --user restart plasma-plasmashell.service"
