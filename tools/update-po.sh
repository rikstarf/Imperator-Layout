#!/usr/bin/env bash
# Refresh po/imperator-layouts.pot from the picker's source and merge it into every po/<lang>.po.
# After running it, translate any new or fuzzy entries by hand. Needs gettext (xgettext, msgmerge).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE"
xgettext --language=JavaScript --from-code=UTF-8 --keyword=_ --add-comments \
  --package-name=imperator-layouts --msgid-bugs-address="" -o po/imperator-layouts.pot imperator-layout-ui
for po in po/*.po; do
  msgmerge --update --backup=none "$po" po/imperator-layouts.pot
done
