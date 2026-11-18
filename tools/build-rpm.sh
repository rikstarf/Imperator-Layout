#!/usr/bin/env bash
# Build the imperator-layouts RPM from this source tree. Output: dist/imperator-layouts-<version>-<release>.noarch.rpm
# Needs: rpmbuild (Fedora: rpm-build), glib-compile-schemas (Fedora: glib2-devel), tar.
# Set IMPERATOR_RPM_NODEPS=1 to skip the BuildRequires check (building on a non-Fedora host).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="$ROOT/packaging/imperator-layouts.spec"
for c in rpmbuild tar glib-compile-schemas; do
  command -v "$c" >/dev/null || { echo "missing command: $c (Fedora: sudo dnf install rpm-build glib2-devel)" >&2; exit 1; }
done

VER="$(sed -n 's/^Version:[[:space:]]*//p' "$SPEC")"
[[ -n "$VER" ]] || { echo "could not read Version from $SPEC" >&2; exit 1; }

TOP="$ROOT/dist/rpmbuild"
rm -rf "$TOP"
mkdir -p "$TOP"/{SOURCES,BUILD,RPMS,SRPMS,SPECS,BUILDROOT}

# Source tarball: the source tree itself (the spec runs tools/stage-extensions.sh on it).
tar -czf "$TOP/SOURCES/imperator-layouts-$VER.tar.gz" -C "$ROOT" \
  --exclude=./dist --exclude=./.git --transform "s,^\.,imperator-layouts-$VER," .

args=(-bb --define "_topdir $TOP")
[[ "${IMPERATOR_RPM_NODEPS:-0}" == 1 ]] && args+=(--nodeps)
rpmbuild "${args[@]}" "$SPEC"

mkdir -p "$ROOT/dist"
cp "$TOP"/RPMS/noarch/*.rpm "$ROOT/dist/"
ls -l "$ROOT"/dist/*.rpm
