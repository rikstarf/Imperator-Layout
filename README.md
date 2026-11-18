# Imperator desktop layouts (Fedora Silverblue)

Vanilla GNOME (the default) plus three layouts (macOS-like, Windows 11-like, ChromeOS-like), built from upstream GPL extensions
(Dash to Dock, Dash to Panel, ArcMenu, Logo Menu, AppMenu, AppIndicator, Light Style) plus two of our own. Design: `DESIGN.md`; licenses and file-level changes: `vendor/NOTICE.md`; packaging: `PACKAGING.md`.

## Use

    sudo rpm-ostree install ./imperator-layouts-<version>.noarch.rpm   # from the USB; then reboot (see PACKAGING.md)
    imperator-layout macos|winlike|chromeos
    imperator-layout-ui     # small window with three named options (also in the app menu as "Desktop Layout")
    imperator-layout check  # state of every managed extension (ACTIVE = working)
    imperator-layout status

Build the RPM with `tools/build-rpm.sh`. Install, site default layout, update, uninstall and the VM checklist are in
`PACKAGING.md`. `./install-layouts.sh` is the per-user development install (no RPM).

Before packaging a profile change, run `tools/check-profiles.py` (checks every section path and key/value against the schemas).

## What each layout uses

| | GNOME (default) | macOS-like | Windows 11-like | ChromeOS-like |
|---|---|---|---|---|
| Menu | stock | Logo Menu + AppMenu (global menu bar) | ArcMenu `11` | ArcMenu `chromebook` |
| Dock / taskbar | stock | Dash to Dock | Dash to Panel | Dash to Panel |
| Panel order | stock | `imperator-panel-order` (Activities and clock moved) | | |

The three layouts also enable AppIndicator, Light Style and `imperator-dock-theme`. **GNOME (default)** enables none of our
extensions and resets our settings (the Dash to Dock, Dash to Panel, ArcMenu, Logo Menu and AppMenu paths, window buttons, hot
corners); the user's own extensions and settings, including light/dark, are left alone. A machine with no layout applied is
already vanilla GNOME, which is why "no site default" means vanilla.

**Transparency presets** (`imperator-layout opacity solid|soft|clear`, also in the picker): `solid` (the default for all three layouts), `soft` and
`clear` set the dock/taskbar opacity to 1.0, 0.85 and 0.6. Only opacity is written, never a
color: the color always comes from the theme (and so follows light/dark). Presets apply to Dash to Dock, Dash to Panel and the stock top panel (macOS layout; the dock-theme extension sets only the alpha
on top of the theme's own panel color, and leaves the overview and lock screen alone). The chosen preset is kept across layout switches.

**Glass effect** (`imperator-layout glass on|off`, a switch in the picker): turns on Blur My Shell (backdrop blur behind the dock or
taskbar, quick settings, menus, calendar and the overview) and `imperator-dock-theme`'s glass look: a fully see-through top bar
with white text and a soft shadow, and a light rim on the dock. It also blurs the space behind every application window and makes the window *backgrounds* translucent (not the text or icons):
the switch writes a marked block into `~/.config/gtk-4.0/gtk.css` and `gtk-3.0/gtk.css`, removed again by turning glass off.
Open apps need a restart to pick it up; Flatpak, Qt, Electron and Firefox windows are not covered. The look is toward white: pale glass with dark text in menus and panels. It is separate from the
transparency presets (while it is on it owns the dock/taskbar/top bar transparency, and the preset returns when it is turned off) and applies to the three layouts; vanilla GNOME stays stock. In the macOS layout the top bar gets no blur at all, only the
see-through strip; with Windows 11-like and ChromeOS-like the Dash to Panel taskbar is blurred. The lock screen and the
screenshot panel are left stock.

**Upgrades:** when the package moves to a new release (MAJOR.MINOR), each user's current layout, glass switch and transparency preset are re-applied once at their next login so new values reach them; hotfix (patch) updates change nothing for the user.

**Languages:** the picker and the Desktop Layout launcher are English and Spanish (follows the system language). Spanish menus
are also shipped for Logo Menu, Dash to Dock, Dash to Panel and AppMenu; ArcMenu brings its own. The CLI (`imperator-layout`)
stays English: it is a technician tool.

## Verified on a Fedora 45 Silverblue VM

- Install works; all five upstream extensions and both of ours load on GNOME 51.
- Windows-like and Chrome OS-like layouts (ArcMenu, Dash to Panel); Chrome OS launcher shows 5 columns.
- macOS-like layout: Dash to Dock, Logo Menu (Terminal opens Ptyxis, power and lock items), panel order across lock/unlock,
  AppMenu (initial run).
- The top bar and dock follow the system light/dark setting once Light Style is enabled.

## Not yet verified

- Multi-monitor behaviour (taskbar index keys vs monitor IDs).
- Tray icons through AppIndicator in the taskbar layouts.
- The layout picker window (`imperator-layout-ui`): syntax-checked only.
- AppMenu in depth: ordering next to Logo Menu, behaviour after lock/unlock, menu coverage per app (partial on Wayland by nature).
- Behaviour after the next Fedora/GNOME release (re-run the extension gate first).

## Known limits

- Overview stays dark with Light Style (upstream behaviour); `imperator-dock-theme` lightens the overview, app grid,
  search results, folders and the dock's icon tiles. The top panel background is untouched.
- Logo Menu has no user item, places or System Settings item, and its default icon list holds other distros' logos
  (the macOS profile uses index 16).

## Patched upstream files

Downstream branding (logos, the Dash to Panel sponsor badge), a few behaviour fixes and one GNOME 51 fix are applied as whole-file
`overrides/` at install time; the vendored originals stay as released. Details in `vendor/NOTICE.md`.

## License

Our own code (`imperator-layout`, `imperator-layout-ui`, `extensions/`, `layouts/`, `tools/`, `packaging/`) is GPL-2.0-or-later; see
`LICENSE`. Vendored extensions keep their own licenses (GPL-2.0-or-later, GPL-2.0, GPL-3.0-or-later; see `vendor/NOTICE.md` and the
LICENSE/COPYING file in each extension folder). `extensions/imperator-panel-order` is derived from a GPL-2.0-or-later extension and its
header keeps the original attribution.
