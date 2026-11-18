#!/usr/bin/env bash
# Maintainer tool: is the bundled extension set ready for the NEXT GNOME major? Run it well before the next Fedora release.
#
# For every extension we ship (vendored upstream ones and our own) it checks:
#   1. does the metadata we ship declare the target GNOME version (offline check)?
#   2. which upstream release supports the target and the current GNOME, and is it newer than the one we ship?
#   3. would one upstream build serve both versions (the seamless upgrade: same files before and after the OS update)?
# It answers one question: can the spec's `Requires: gnome-shell < N` gate be raised, and what must be re-vendored first.
# It never changes anything. Needs python3 and network access to extensions.gnome.org and gitlab.gnome.org (a normal machine; not
# a locked-down build host).
#
# Usage: tools/check-upstream.sh [--target N]      (default target = the spec's gnome-shell upper bound, e.g. < 52 -> 52)
# Exit: 0 = every extension is ready, 1 = something blocks or needs re-vendoring, 2 = could not reach upstream for some of them.
# Test hook: CHECK_UPSTREAM_FIXTURES=<dir> reads <dir>/<uuid>.json (extensions.gnome.org format) and <dir>/gnome-tags-<N>.json
# instead of the network.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="$HERE/packaging/imperator-layouts.spec"
TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:?--target needs a GNOME major version}"; shift 2 ;;
    -h|--help) sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "usage: tools/check-upstream.sh [--target N]" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null || { echo "missing command: python3" >&2; exit 2; }

if [[ -z "$TARGET" ]]; then
  TARGET="$(sed -n 's/^Requires:[[:space:]]*gnome-shell[[:space:]]*<[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$SPEC" | head -n1)"
  [[ -n "$TARGET" ]] || { echo "could not read the gnome-shell upper bound from the spec; pass --target N" >&2; exit 2; }
fi

HERE="$HERE" TARGET="$TARGET" exec python3 -I - <<'PY'
import json, os, re, sys, glob, urllib.request, urllib.parse, urllib.error

here, target = os.environ["HERE"], os.environ["TARGET"]
current = str(int(target) - 1)
fixtures = os.environ.get("CHECK_UPSTREAM_FIXTURES")

def fetch(url, fixture_name):
    if fixtures:
        path = os.path.join(fixtures, fixture_name)
        if not os.path.exists(path):
            raise FileNotFoundError(path)
        return json.load(open(path))
    req = urllib.request.Request(url, headers={"User-Agent": "imperator-layouts check-upstream"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.load(r)

def vnum(v):
    try:
        return float(str(v))
    except ValueError:
        return -1.0

# What we ship: every extension folder, its declared shell versions, and (for vendored ones) the version and upstream source.
shipped = {}
for d in sorted(glob.glob(f"{here}/vendor/extensions/*/") + glob.glob(f"{here}/extensions/*/")):
    uuid = os.path.basename(d.rstrip("/"))
    meta = json.load(open(os.path.join(d, "metadata.json")))
    shipped[uuid] = {"own": "/vendor/" not in d, "declares": [str(v) for v in meta.get("shell-version", [])], "meta_version": meta.get("version")}
sources = {}
for line in open(f"{here}/vendor/versions.tsv"):
    if line.strip() and not line.startswith("#"):
        uuid, version, src = line.rstrip("\n").split("\t")
        sources[uuid] = (version, src)

rows, blockers, unknown = [], 0, 0
for uuid, s in shipped.items():
    declares_target = target in s["declares"] or any(v.split(".")[0] == target for v in s["declares"])
    if s["own"]:
        rows.append((uuid, "own", "-", "yes" if declares_target else "NO", "-", "READY" if declares_target else "ADD 52 AFTER TESTING"))
        if not declares_target:
            blockers += 1
        continue
    version, src = sources.get(uuid, (None, None))
    if src is None:
        rows.append((uuid, "?", "?", "yes" if declares_target else "NO", "?", "not listed in vendor/versions.tsv"))
        blockers += 1
        continue
    try:
        if src == "ego":
            info = fetch("https://extensions.gnome.org/extension-info/?" + urllib.parse.urlencode({"uuid": uuid}), uuid + ".json")
            vmap = info.get("shell_version_map", {})
            def latest(major):
                best = None
                for k, v in vmap.items():
                    if k.split(".")[0] == major or k == major:
                        n = v.get("version") if isinstance(v, dict) else v
                        if best is None or vnum(n) > vnum(best):
                            best = n
                return best
            up_target, up_current = latest(target), latest(current)
        else:  # gnome gitlab tags: <shell version>.<patch>, plus alpha/beta/rc
            tags = fetch("https://gitlab.gnome.org/api/v4/projects/GNOME%2Fgnome-shell-extensions/repository/tags?search=" + target,
                         f"gnome-tags-{target}.json")
            names = [t["name"] for t in tags if t["name"].startswith(target + ".")]
            up_target = sorted(names)[-1] if names else None
            up_current = version
    except (urllib.error.URLError, OSError, ValueError, KeyError) as e:
        rows.append((uuid, version, "?", "yes" if declares_target else "NO", "?", f"UNKNOWN ({type(e).__name__})"))
        unknown += 1
        continue
    if up_target is None:
        verdict = "WAIT: no upstream release for GNOME " + target + " yet" if not declares_target else "READY (declared; upstream list has no " + target + " build, verify)"
        if not declares_target:
            blockers += 1
        rows.append((uuid, version, "none", "yes" if declares_target else "NO", "-", verdict))
        continue
    newer = vnum(up_target) > vnum(version)
    same_build = (str(up_target) == str(up_current)) if src == "ego" else False
    if src == "gnome":
        # light-style ships with each GNOME release; our copy is regenerated from the tag for the new version.
        verdict = f"UPDATE: re-vendor tag {up_target} (regenerate metadata)"
        blockers += 1
    elif newer:
        verdict = f"UPDATE to {up_target} (re-vendor)"
        blockers += 1
    elif declares_target:
        verdict = "READY"
    else:
        # Upstream's build for the new GNOME is the one we ship, but our copy does not declare it: add it after testing.
        verdict = f"ADD {target} to shell-version after testing (upstream lists it for this build)"
        blockers += 1
    rows.append((uuid, version, str(up_target), "yes" if declares_target else "NO",
                 ("same build" if same_build else f"differs from {current} build ({up_current})") if src == "ego" else "-", verdict))

w = [max(len(str(r[i])) for r in rows + [("extension", "shipped", "upstream " + target, "declares " + target, "vs GNOME " + current, "verdict")]) for i in range(6)]
hdr = ("extension", "shipped", "upstream " + target, "declares " + target, "vs GNOME " + current, "verdict")
for r in [hdr] + rows:
    print("  ".join(str(c).ljust(w[i]) for i, c in enumerate(r)))
print()
if blockers:
    print(f"NOT READY for GNOME {target}: {blockers} extension(s) need work (see verdict column).")
elif unknown:
    print(f"UNKNOWN: could not reach upstream for {unknown} extension(s); run again with network access.")
else:
    print(f"Every extension is ready for GNOME {target} on paper.")
print()
print("What this does not tell you (do these on a Fedora VM with the new GNOME before raising the gate):")
print("  - each layout with glass on and off, light and dark, lock/unlock, multi-monitor, suspend/resume, logout/login")
print("  - extensions that declare the new version can still break at runtime; check `journalctl --user -b | grep -i gnome-shell`")
print("  - our overrides/ files (patched against the CURRENT upstream) still apply to the re-vendored sources")
print(f"To raise the gate: add \"{target}\" to shell-version in the metadata of our own extensions, re-vendor what is flagged UPDATE,")
print(f"set `Requires: gnome-shell < {int(target) + 1}` in the spec, bump the release, publish. A release that works on both {current} and {target}")
print("makes the OS upgrade invisible to users.")
sys.exit(1 if blockers else (2 if unknown else 0))
PY
