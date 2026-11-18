#!/usr/bin/env bash
# Build, sign and publish a release: the signed RPM repo (GitHub Pages, branch gh-pages) and a GitHub release with the RPM.
# Run on the maintainer's machine: it needs the private signing key. Nothing here ever reads or stores the key itself.
#
# Needs: rpmbuild glib-compile-schemas (tools/build-rpm.sh), rpmsign rpmkeys createrepo_c gpg git; gh (optional, for the release).
#   Fedora/Nobara: sudo dnf install -y rpm-build glib2-devel gettext rpm-sign createrepo_c gnupg2 git gh
#
# Usage:  tools/publish-repo.sh            # builds, signs, publishes the version in packaging/imperator-layouts.spec
# Env:    IMPERATOR_SIGN_FPR      signing key fingerprint (default: the Imperator release key)
#         IMPERATOR_PUBLISH_REMOTE  git remote to push to (default: origin)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="$ROOT/packaging/imperator-layouts.spec"
KEYFILE="$ROOT/packaging/RPM-GPG-KEY-imperator"
FPR="${IMPERATOR_SIGN_FPR:-26E7E9C6F89E1D068170E6D6D8A96E9D5B54D44B}"
REMOTE="${IMPERATOR_PUBLISH_REMOTE:-origin}"
BRANCH="gh-pages"
KEEP=3

die() { echo "error: $*" >&2; exit 1; }
for c in rpmbuild rpmsign rpmkeys createrepo_c gpg git; do
  command -v "$c" >/dev/null || die "missing command: $c"
done

VER="$(sed -n 's/^Version:[[:space:]]*//p' "$SPEC")"
[[ -n "$VER" ]] || die "could not read Version from $SPEC"
RPM="$ROOT/dist/imperator-layouts-$VER-1.noarch.rpm"

# The release must come from a clean, pushed commit, so the tag and the RPM match what is public.
cd "$ROOT"
[[ -z "$(git status --porcelain)" ]] || die "uncommitted changes: commit and push first"
git fetch -q "$REMOTE"
UPSTREAM="$(git rev-parse '@{u}' 2>/dev/null)" || die "current branch has no upstream"
[[ "$(git rev-parse HEAD)" == "$UPSTREAM" ]] || die "HEAD is not pushed: push first"

# The key in the repo must be the one we are about to sign with.
GOT="$(gpg --show-keys --with-colons "$KEYFILE" | awk -F: '$1=="fpr"{print $10; exit}')"
[[ "$GOT" == "$FPR" ]] || die "packaging/RPM-GPG-KEY-imperator is $GOT, expected $FPR"
gpg --list-secret-keys "$FPR" >/dev/null 2>&1 || die "no secret key $FPR in this keyring"

echo "== building $VER"
"$ROOT/tools/build-rpm.sh"
[[ -f "$RPM" ]] || die "build did not produce $RPM"

echo "== signing"
rpmsign --addsign --define "_gpg_name $FPR" "$RPM"
TMPDB="$(mktemp -d)"
trap 'rm -rf "$TMPDB"' EXIT
rpmkeys --dbpath "$TMPDB" --import "$KEYFILE"
rpmkeys --dbpath "$TMPDB" --checksig "$RPM" | tee /dev/stderr | grep -q "signatures OK" || die "signature check failed"

echo "== publishing repo to $REMOTE/$BRANCH"
PAGES="$ROOT/dist/pages"
git worktree prune
rm -rf "$PAGES"
if git ls-remote --exit-code --heads "$REMOTE" "$BRANCH" >/dev/null 2>&1; then
  git fetch -q "$REMOTE" "$BRANCH"
  git worktree add -q -B "$BRANCH" "$PAGES" "$REMOTE/$BRANCH"
else
  git worktree add -q --detach "$PAGES"
  git -C "$PAGES" checkout -q --orphan "$BRANCH"
  git -C "$PAGES" rm -rfq . 2>/dev/null || true
fi

mkdir -p "$PAGES/repo"
cp "$RPM" "$PAGES/repo/"
# Keep the newest $KEEP RPMs.
# shellcheck disable=SC2012
ls -1 "$PAGES"/repo/imperator-layouts-*.noarch.rpm | sort -V | head -n -"$KEEP" | xargs -r rm -f
createrepo_c -q --update --no-database "$PAGES/repo"
rm -f "$PAGES/repo/repodata/repomd.xml.asc"
gpg --batch --yes --local-user "$FPR" --detach-sign --armor \
  -o "$PAGES/repo/repodata/repomd.xml.asc" "$PAGES/repo/repodata/repomd.xml"
cp "$KEYFILE" "$PAGES/RPM-GPG-KEY-imperator"
touch "$PAGES/.nojekyll"

git -C "$PAGES" add -A
if git -C "$PAGES" diff --cached --quiet; then
  echo "repo unchanged"
else
  git -C "$PAGES" commit -q -m "Publish imperator-layouts $VER"
  git -C "$PAGES" push -q "$REMOTE" "$BRANCH"
fi
git worktree remove --force "$PAGES"

echo "== release v$VER"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  if gh release view "v$VER" >/dev/null 2>&1; then
    gh release upload "v$VER" "$RPM" --clobber
  else
    gh release create "v$VER" "$RPM" --target "$(git rev-parse HEAD)" --title "imperator-layouts $VER" \
      --notes "Signed RPM (key fingerprint $FPR). Install: rpm-ostree install on Silverblue, dnf install on Fedora Workstation."
  fi
else
  echo "gh is missing or not logged in. Create the release by hand:"
  echo "  gh release create v$VER $RPM --title 'imperator-layouts $VER'"
fi
echo "done: $VER"
