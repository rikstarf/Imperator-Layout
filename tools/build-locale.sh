#!/usr/bin/env bash
# Compile the picker's translations: po/<lang>.po -> DEST/<lang>/LC_MESSAGES/imperator-layouts.mo
# Used by the RPM build (DEST = a staging tree) and by install-layouts.sh (DEST = ~/.local/share/locale).
# English is the source language and needs no catalog.
# Usage: tools/build-locale.sh DEST
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:?usage: build-locale.sh DEST}"
command -v msgfmt >/dev/null || { echo "missing command: msgfmt (Fedora: gettext)" >&2; exit 1; }

for po in "$HERE"/po/*.po; do
  lang="$(basename "$po" .po)"
  mkdir -p "$DEST/$lang/LC_MESSAGES"
  msgfmt --check-format -o "$DEST/$lang/LC_MESSAGES/imperator-layouts.mo" "$po"
  echo "locale: $lang"
done
