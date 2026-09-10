# Plasma 6 DP-2 / DP-3 Monitor Toggle

A KDE Plasma 6 panel widget for Wayland that toggles two DisplayPort monitors (`DP-2` and `DP-3`) together using `kscreen-doctor`.

## Current display profile

This repository is configured for the following layout:

- **DP-1** — primary display; position restored to `1271,550` when the side displays return
- **DP-2** — 1920×1080 @ 60 Hz, scale 0.85, rotated right, position `0,0`, priority 3
- **DP-3** — 1920×1080 @ 74.97 Hz, scale 1.0, normal rotation, position `3831,550`, priority 2

DP-1's resolution, refresh rate, HDR, scale, and rotation are otherwise left untouched.

## Wayland behavior

The widget uses KScreen/`kscreen-doctor` only. It does not use `xrandr`.

Turning the side displays back on is intentionally staged:

1. Enable DP-2 and DP-3.
2. Wait 750 ms for KWin/KScreen to recreate the outputs.
3. Restore mode, scale, rotation, priority, and position.

This avoids the unreliable one-shot restore behavior seen when fully disabled outputs are re-enabled under Wayland.

## Install

```bash
git clone https://github.com/newnetmp3/plasma6-dp-monitor-toggle.git
cd plasma6-dp-monitor-toggle
./install.sh
```

Then right-click the Plasma panel, choose **Add Widgets**, and search for **DP-2 + DP-3 Toggle**.

If necessary, restart Plasma:

```bash
systemctl --user restart plasma-plasmashell.service
```

## Uninstall

```bash
./uninstall.sh
```

## Customizing for another monitor layout

Edit `package/contents/ui/main.qml` and change the connector names and restore commands (`enableCommand`, `restoreCommand`, and `offCommand`) to match the output from:

```bash
kscreen-doctor -o
```

## Version

Current version: **1.0.7**

## License

MIT
