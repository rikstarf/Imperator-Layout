#!/usr/bin/env bash
# Stage the extensions the way they must be installed: vendored + own extensions copied into DEST/<uuid>/,
# schemas compiled, overrides/ applied on top. Used by install-layouts.sh (DEST = ~/.local/share/gnome-shell/extensions)
# and by build-rpm.sh (DEST = a staging tree).
# Usage: tools/stage-extensions.sh DEST
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:?usage: stage-extensions.sh DEST}"

command -v glib-compile-schemas >/dev/null || { echo "missing command: glib-compile-schemas" >&2; exit 1; }
mkdir -p "$DEST"

for dir in "$HERE"/vendor/extensions/*/ "$HERE"/extensions/*/; do
  uuid="$(basename "$dir")"
  rm -rf "${DEST:?}/${uuid:?}"
  cp -a "$dir" "$DEST/$uuid"
  echo "staged: $uuid"
done

# Overrides: whole files replace the vendored ones (GNOME 51 fixes, Zorin branding removal; see vendor/NOTICE.md).
for odir in "$HERE"/overrides/*/; do
  [[ -d "$odir" ]] || continue
  uuid="$(basename "$odir")"
  [[ -d "$DEST/$uuid" ]] || { echo "override for missing extension: $uuid" >&2; exit 1; }
  cp -a "$odir"/. "$DEST/$uuid/"
  echo "overrides applied: $uuid"
done

# Translations: translations/<uuid>/<lang>.po -> <uuid>/locale/<lang>/LC_MESSAGES/<gettext-domain>.mo
# (upstream catalogs we restored plus our own; the domain is the one the extension's metadata.json declares).
if compgen -G "$HERE/translations/*/*.po" >/dev/null; then
  command -v msgfmt >/dev/null || { echo "missing command: msgfmt (Fedora: gettext)" >&2; exit 1; }
  for tdir in "$HERE"/translations/*/; do
    uuid="$(basename "$tdir")"
    [[ -d "$DEST/$uuid" ]] || { echo "translations for missing extension: $uuid" >&2; exit 1; }
    domain="$(sed -n 's/.*"gettext-domain"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$DEST/$uuid/metadata.json" | head -n1)"
    [[ -n "$domain" ]] || { echo "no gettext-domain in $uuid/metadata.json" >&2; exit 1; }
    for po in "$tdir"*.po; do
      lang="$(basename "$po" .po)"
      mkdir -p "$DEST/$uuid/locale/$lang/LC_MESSAGES"
      msgfmt -o "$DEST/$uuid/locale/$lang/LC_MESSAGES/$domain.mo" "$po"
      echo "translation: $uuid $lang ($domain)"
    done
  done
fi

# Compile whatever schema each extension carries (after overrides, so a patched schema would be picked up).
for dir in "$DEST"/*/; do
  if compgen -G "$dir/schemas/*.gschema.xml" >/dev/null; then
    glib-compile-schemas "$dir/schemas"
  fi
done
