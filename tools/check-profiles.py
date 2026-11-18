#!/usr/bin/env python3
"""Validate layouts/*.dconf against the vendored GSettings schemas.

For every [org/gnome/shell/extensions/...] section: the path must be a real schema path (dconf paths are
case-sensitive) and every key/value must be accepted by that schema. Needs glib-compile-schemas and gsettings.
Usage: tools/check-profiles.py   (run from anywhere)
"""
import glob, os, re, subprocess, sys, tempfile, shutil

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
xmls = glob.glob(f"{root}/vendor/schemas/*.xml") + glob.glob(f"{root}/vendor/extensions/*/schemas/*.xml") + glob.glob(f"{root}/extensions/*/schemas/*.xml")
tmp = tempfile.mkdtemp()
paths = {}
for x in xmls:
    shutil.copy(x, tmp)
    for m in re.finditer(r'<schema\b([^>]*)>', open(x).read()):
        a = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        if 'path' in a:
            paths[a['path'].strip('/')] = a['id']
subprocess.run(['glib-compile-schemas', tmp], check=True)
env = dict(os.environ, GSETTINGS_SCHEMA_DIR=tmp, GSETTINGS_BACKEND='memory')
bad = n = 0
for f in sorted(glob.glob(f"{root}/layouts/*.dconf")):
    schema = None
    for line in open(f):
        line = line.rstrip('\n')
        if line.startswith('['):
            sec = line[1:-1]
            schema = None
            if sec.startswith('org/gnome/shell/extensions/'):
                schema = paths.get(sec)
                if not schema:
                    near = [p for p in paths if p.lower() == sec.lower()]
                    print(f"BAD  {os.path.basename(f)} [{sec}] no such schema path" + (f" (did you mean {near[0]}?)" if near else ""))
                    bad += 1
            continue
        if schema and '=' in line and not line.lstrip().startswith('#'):
            k, v = line.split('=', 1); n += 1
            r = subprocess.run(['gsettings', 'set', schema, k, v], env=env, capture_output=True, text=True)
            if r.returncode:
                bad += 1
                print(f"BAD  {os.path.basename(f)} {schema} {k}={v[:50]}: {r.stderr.strip()[:100]}")
shutil.rmtree(tmp)
print(f"{n} keys checked, {bad} problems")
sys.exit(1 if bad else 0)
