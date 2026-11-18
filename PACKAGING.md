# Packaging and deployment (RPM)

The layouts ship as one self-contained noarch RPM, `imperator-layouts`, for Fedora Silverblue (`rpm-ostree`) and regular Fedora
Workstation (`dnf`). The first install can come from a local file (the deployer USB) with no network: every extension, including
AppIndicator and Light Style, is bundled. The RPM also installs `imperator.repo` and the release public key, so afterwards
`rpm-ostree upgrade` / `dnf upgrade` fetch new signed releases from the Imperator repo (GitHub Pages).

## What the RPM installs

| Path | Content |
|---|---|
| `/usr/share/gnome-shell/extensions/<uuid>/` | all extensions (vendored upstream + ours), overrides applied, schemas compiled |
| `/usr/share/imperator-layouts/` | `imperator-layout`, `imperator-layout-ui`, `layouts/*.dconf` |
| `/usr/bin/imperator-layout`, `/usr/bin/imperator-layout-ui` | symlinks into the line above |
| `/etc/yum.repos.d/imperator.repo`, `/etc/pki/rpm-gpg/RPM-GPG-KEY-imperator` | the update repo (gpgcheck and repo_gpgcheck on) and its signing key |
| `/usr/share/applications/imperator-layouts.desktop` | "Desktop Layout" launcher for the picker (English and Spanish names) |
| `/usr/share/locale/es/LC_MESSAGES/imperator-layouts.mo` | Spanish translation of the picker (English is the source text) |
| `<extension>/locale/es/...` (inside each extension dir) | Spanish menus for Logo Menu, Dash to Dock, Dash to Panel and AppMenu (ArcMenu ships its own) |
| `/etc/xdg/autostart/imperator-layouts-firstrun.desktop` | runs `imperator-layout firstrun` at login |
| `/etc/imperator-layouts/default-layout` | site default layout (config file, kept across upgrades) |
| `/usr/share/doc/imperator-layouts/`, `/usr/share/licenses/imperator-layouts/` | README, DESIGN, this file, NOTICE and COPYING |

Requires `gnome-shell >= 51`, so the package refuses to install on an older GNOME. That is the update gate in
`DESIGN.md` expressed as a dependency: bump it only after every bundled extension has been checked on the new version.

## Build

On a Fedora machine (your Nobara desktop works):

    sudo dnf install rpm-build glib2-devel gettext
    cd ~/Documents/Scripts/skin/imperator-layouts
    tools/build-rpm.sh

Output: `dist/imperator-layouts-<version>-<release>.noarch.rpm` (`dist/` is git-ignored). The spec copies the source tree,
runs `tools/stage-extensions.sh` (copy extensions, apply `overrides/`, compile translations and schemas) and `tools/build-locale.sh` (the picker's catalog) and installs the result.
On a non-Fedora host set `IMPERATOR_RPM_NODEPS=1` to skip the BuildRequires check. To release a new build, raise `Version`
(or `Release`) and add a `%changelog` entry in `packaging/imperator-layouts.spec`.

## Install from the USB

Copy the `.rpm` onto the USB next to the deployer scripts. On the client:

    sudo rpm-ostree install /run/media/<user>/<usb-label>/imperator-layouts-1.0.0-1.noarch.rpm
    systemctl reboot

`rpm-ostree` builds a new deployment containing the package and boots into it; that is why one reboot is needed. Nothing
is fetched from the network because the package has no dependencies outside the base Silverblue image
(`gnome-shell`, `dconf`, `glib2`, `gjs`, `libadwaita`).

### Choose the default layout for the machine (optional)

`/etc` is writable on Silverblue, so the deployer can set the site default before the first user logs in:

    echo winlike | sudo tee /etc/imperator-layouts/default-layout

(`gnome`, `macos`, `winlike` or `chromeos`; `gnome` is vanilla GNOME.) At each user's first login `imperator-layout firstrun` applies it once, if that user has
no layout yet. With no layout named in the file, nothing is applied (the desktop stays vanilla GNOME) and users pick one themselves from the "Desktop Layout"
app or with `imperator-layout <name>`. A user's own choice is never overwritten: `firstrun` skips anyone who already has
`~/.config/imperator-layouts/current`.

## Update and uninstall

    # update: replace the layered package in one transaction
    sudo rpm-ostree uninstall imperator-layouts --install /path/to/imperator-layouts-<new version>.noarch.rpm
    systemctl reboot

    # remove
    sudo rpm-ostree uninstall imperator-layouts
    systemctl reboot

Removing the package does not touch per-user state: each user keeps their dconf settings, the `enabled-extensions` list
(it will then name extensions that no longer exist, which GNOME ignores) and `~/.config/imperator-layouts/current`.
To reset a user to stock GNOME: delete that file and run `dconf reset -f /org/gnome/shell/extensions/` and
`gsettings reset org.gnome.shell enabled-extensions`.

## Regular Fedora Workstation

`sudo dnf install ./imperator-layouts-<version>.noarch.rpm`, no reboot needed; log out and in. Updates: `sudo dnf upgrade`.
The package requires `gnome-shell >= 51` and `< 52`, so it will not install on an untested GNOME major.

## Publishing a release (maintainer)

Done on the maintainer's machine, which holds the private signing key (never in the repo):

1. Bump `Version:` and add the `%changelog` entry in the spec, commit and push.
2. `tools/publish-repo.sh`: builds the RPM, signs it (`rpmsign`), checks the signature, adds it to the `gh-pages` branch
   (`repo/`, the newest three RPMs), regenerates and signs the metadata (`createrepo_c`, detached `repomd.xml.asc`), pushes, and
   creates the GitHub release `v<version>` with the RPM attached (needs `gh auth login`).
3. GitHub Pages must serve `gh-pages` (repo Settings, Pages, deploy from branch, root). The repo URL is
   `https://rikstarf.github.io/Imperator-Layout/repo/`.
4. `usb-sync.sh` in the deployer repo downloads the latest release RPM, verifies it against the pinned key and puts it in the USB root.

To support a new GNOME major, vet it first (see DESIGN.md, Update gate), then raise the `gnome-shell <` cap in the spec and publish.

## Development install (no RPM)

`./install-layouts.sh` installs the same content under `$HOME` (`~/.local/share/gnome-shell/extensions`, `~/.local/bin`) from
the source tree, using the same `tools/stage-extensions.sh` (needs `msgfmt`; the picker's Spanish catalog goes to `~/.local/share/locale`). Use it on a test VM; log out and in afterwards because GNOME
Shell on Wayland only discovers new per-user extensions at login. With the RPM the extensions already exist at boot, so
`firstrun` should be able to enable them without a second logout (checklist item 3 confirms it).

## What was verified

- RPM contents, metadata, scripts and dependencies, on the build host (see the checklist's first block).
- `imperator-layout firstrun` against stubbed `dconf`/`gsettings`/`gnome-extensions` in a scratch root.

## Not yet verified on a real Silverblue VM

Run these once on the VM, in order, and note anything that differs:

1. `sudo rpm-ostree install ./imperator-layouts-1.0.0-1.noarch.rpm` accepts an unsigned local file without asking for a key.
2. After the reboot, `imperator-layout check` lists every extension (state may read INACTIVE until a layout is applied).
3. `echo macos | sudo tee /etc/imperator-layouts/default-layout`, log out and in with a fresh user: the layout appears
   without a further logout, and `journalctl --user -t imperator-layouts` shows no error.
4. A second login keeps the layout and does not re-run it; `imperator-layout winlike` then `check` shows ArcMenu and
   Dash to Panel ACTIVE.
5. `sudo rpm-ostree uninstall imperator-layouts --install <rpm>` with a newer release works (or note the error).
6. The "Desktop Layout" launcher appears in the app grid and switches layouts.
7. Vanilla: choose "GNOME (default)" in the picker; extensions and the dock/taskbar disappear, window buttons and hot corners
   return to stock, and switching back to a layout restores it.
8. Transparency: with the Windows-like or macOS-like layout pick Soft, then Clear, then Solid (the default); the taskbar/dock changes
   each time, the color stays the theme's (check once in light and once in dark), and the choice survives switching layouts.
   In the macOS layout the top bar follows too. Look at Clear on a bright wallpaper: if the taskbar text is hard to read, say so and the values get changed.
9. Glass: with the macOS layout turn on "Glass effect" in the picker (or `imperator-layout glass on`; log out and in once if the
   blur does not appear). Check: the top bar is a see-through strip with readable text on a bright and a dark wallpaper; the dock
   shows blurred windows/wallpaper behind it with a thin light rim; the quick settings panel, calendar and right-click menus are
   blurred; the overview is blurred; the lock screen is unchanged. Then switch to Windows 11-like and ChromeOS-like and look
   at the Dash to Panel taskbar. Report what looks wrong or too heavy. Turn the switch off: everything returns to stock.
10. Spanish: set the system language to Español, log out and in. The picker, the launcher name, Logo Menu items, ArcMenu and the
   AppMenu top-level menus (Archivo, Editar, Ver, Ir, Ventana, Ayuda) show in Spanish; an app that exports its own Spanish menu
   shows a single "Ventana" menu, not two.

Also still open from before: multi-monitor behaviour, AppIndicator tray icons in the taskbar layouts, and AppMenu coverage.

## Upgrading

Install a newer RPM with `rpm-ostree uninstall imperator-layouts && rpm-ostree install <new.rpm>` and reboot. At the next login each user
with a layout is re-applied once if the release (MAJOR.MINOR) changed, so new profile values reach them; a hotfix (1.3.0 -> 1.3.1) changes
nothing for the user. Check with `cat ~/.config/imperator-layouts/release` and `journalctl -b -t imperator-layouts`.
Before uninstalling for good, run `imperator-layout gnome` (resets our settings and removes the glass block from gtk.css).

## Before each new GNOME major (the update gate)

The spec holds the package on the GNOME it was tested on (`Requires: gnome-shell >= 51` and `< 52`), so a Fedora upgrade cannot pull
users onto a GNOME the bundled extensions have not been vetted for. Start preparing as soon as the next GNOME has a beta:

```
tools/check-upstream.sh              # target = the spec's upper bound (52 today); or --target N
```

It lists, per extension, whether the metadata we ship declares the new version, which upstream release supports it, and whether one
build serves both the current and the new GNOME (the seamless case). It needs network access (run it on a normal machine). Versions
it compares against live in `vendor/versions.tsv`: update that file and the table in `vendor/NOTICE.md` whenever an extension is
re-vendored. Then test on a VM with the new GNOME (layouts, glass on and off, light and dark, lock, multi-monitor, suspend), raise the
gate, publish.
