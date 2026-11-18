#!/usr/bin/env bash
# Per-user install of the extensions + layout profiles, straight from this source tree (development and testing).
# The deployment path is the RPM (see PACKAGING.md); this script does the same job under $HOME without layering anything.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DEST="$HOME/.local/share/gnome-shell/extensions"
SHARE="$HOME/.local/share/imperator-layouts"
BIN="$HOME/.local/bin"

for c in glib-compile-schemas gnome-extensions msgfmt; do
  command -v "$c" >/dev/null || { echo "missing command: $c" >&2; exit 1; }
done

mkdir -p "$EXT_DEST" "$SHARE" "$BIN"

# Upstream extensions and our own replaced the old Zorin extensions (dash, taskbar, move-clock, menu); remove old copies if an earlier install left them.
rm -rf "${EXT_DEST:?}/zorin-dash@zorinos.com" "${EXT_DEST:?}/zorin-taskbar@zorinos.com" "${EXT_DEST:?}/zorin-hide-activities-move-clock@zorinos.com" "${EXT_DEST:?}/zorin-menu@zorinos.com"

"$HERE/tools/stage-extensions.sh" "$EXT_DEST"
"$HERE/tools/build-locale.sh" "$HOME/.local/share/locale"

rm -rf "$SHARE/layouts"
cp -a "$HERE/layouts" "$SHARE/layouts"
install -m 0755 "$HERE/imperator-layout" "$SHARE/imperator-layout"
ln -sf "$SHARE/imperator-layout" "$BIN/imperator-layout"
install -m 0755 "$HERE/imperator-layout-ui" "$SHARE/imperator-layout-ui"
ln -sf "$SHARE/imperator-layout-ui" "$BIN/imperator-layout-ui"

# App launcher so the picker shows up in the app grid / menu search.
APPS="$HOME/.local/share/applications"
mkdir -p "$APPS"
cat > "$APPS/imperator-layouts.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Desktop Layout
Name[es]=Diseño del escritorio
Comment=Choose how the desktop looks and behaves.
Comment[es]=Elige cómo se ve y cómo funciona el escritorio.
Exec=gjs -m $SHARE/imperator-layout-ui
Icon=preferences-desktop-appearance
Terminal=false
Categories=Settings;GTK;
StartupNotify=true
DESKTOP
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" || true
command -v gjs >/dev/null || echo "warning: gjs not found (needed by the layout picker)" >&2

echo
echo "Done. Log out and back in so GNOME loads the new extensions, then run:"
echo "  imperator-layout macos|winlike|chromeos"
