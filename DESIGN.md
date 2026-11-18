# Design

How the layouts work and why. Usage is in `README.md`, packaging in `PACKAGING.md`, licenses in `vendor/NOTICE.md`.

## Goals

- A desktop that looks and behaves like macOS, Windows 11 or ChromeOS on Fedora Silverblue (GNOME), or plain GNOME, switchable
  per user, installed as one RPM.
- No custom shell theme and no colors of our own: the panels follow the active GNOME light/dark setting.
- Reproducible: extensions are vendored at pinned versions and shipped in the RPM. Nothing is downloaded at install time.

## How a layout is applied

- A layout is a set of dconf profiles in `layouts/`: `base.dconf` plus `<layout>.dconf`. `imperator-layout <name>` loads them,
  rewrites `enabled-extensions` to the layout's set (`COMMON` plus the layout's extras) and records the choice and the package
  release under `~/.config/imperator-layouts/`.
- Layouts: `gnome` (vanilla: strips our extensions, resets our dconf paths), `macos` (Logo Menu, AppMenu, Dash to Dock,
  `imperator-panel-order`), `winlike` and `chromeos` (ArcMenu plus Dash to Panel).
- `tools/check-profiles.py` validates every dconf section path and key/value against the schemas of the vendored and own extensions.
  dconf paths are case-sensitive (Logo Menu's is `Logo-menu`), so a wrong path would silently write where nothing reads.
- Wayland loads extensions at login, so a changed extension set needs a log out and back in. `imperator-layout check` reports
  extension state.

## Panel color policy

- No layout profile sets a panel color. Dash to Panel and Dash to Dock take their color from the shell theme, and the vendored
  Light Style extension makes that follow the system light/dark setting.
- **Transparency presets** `solid` (default), `soft` (0.85), `clear` (0.6) write opacity only (`layouts/opacity-*.dconf`). The stock
  top bar (macOS layout) is handled by our `imperator-dock-theme` extension, which reads the theme's own color and sets only the alpha.
- **Light top bar (macOS layout):** the dock is forced light, and the same alpha on a dark bar looks different, so on this layout the
  top bar is tinted with the dock's light color in light mode (dark text via a style class). Not applied with glass on, in dark
  mode, in the overview or on the lock screen.

## Glass

- Glass is exclusive to the macos layout (`glass_active` in the script): other layouts refuse `glass on`, applying another layout unloads it, the stored switch is kept for when macos returns. While active, `opacity` refuses (glass owns dock/top-bar alpha). Blur radius 80 shared, 180 for windows.
- Glass follows the color scheme: BMS pipelines and popup/dock styles are on automatic; `glass-dark.css` loads on top of `glass.css` in dark mode. Windows use their own stronger pipelines (`imperator_window_*`, set through the `pipelines` key in `glass.dconf`).
- One switch, `imperator-layout glass on|off`, independent of layout and preset. It enables Blur My Shell (vendored, configured from
  dconf in `layouts/glass.dconf` and per-layout `glass-<layout>.dconf`): blur behind the dock, menus and overview, a see-through top
  bar with white text, and a dock-like tinted quick-settings panel. No refraction.
- Window translucency comes from a marked block in the user's `~/.config/gtk-4.0/gtk.css` and `gtk-3.0/gtk.css` that gives the named
  background colors an alpha. Text and icons are unaffected. GTK reads these files only when an app starts, so already-open apps keep
  their old look, and Files (which stays resident) is quit on each toggle. Flatpak, Qt, Electron and Firefox apps do not read these
  files and are not covered.

## Upgrades

- Version is `MAJOR.MINOR.PATCH`. The spec's `Version:` and top `%changelog` entry are the only place to change it; the RPM ships
  `/usr/share/imperator-layouts/VERSION`.
- `imperator-layout firstrun` runs at login. When the package's MAJOR.MINOR differs from the stored one, it re-applies the current
  layout (which restores glass and preset settings). Patch updates do nothing. A missing record is only recorded. A dev checkout has
  no VERSION and never re-applies.

## Update gate

- Move to a new Fedora/GNOME release only when every bundled extension declares that GNOME version and passes a canary run (login,
  lock, multi-monitor, suspend/resume, each layout with glass on and off). The spec's `Requires: gnome-shell` expresses the gate.
- During a transition one RPM must work on both GNOME versions, so a vendored extension update must declare both, or be patched in
  `overrides/`.

## Own code and overrides

- `imperator-layout` (bash), `imperator-layout-ui` (GJS, libadwaita, Spanish and English), `imperator-dock-theme` (light-dock
  styling, panel opacity, glass styling), `imperator-panel-order` (Activities and clock on the right; re-applied after every panel
  rebuild, which GNOME does on lock and unlock).
- `overrides/<uuid>/` holds whole-file replacements applied on top of the vendored originals at staging time
  (`tools/stage-extensions.sh`), which also compiles schemas and translations. The vendored originals stay as released. Each
  override is listed in `vendor/NOTICE.md`.
- ArcMenu reloads when Dash to Panel becomes active and can read a panel that is not built yet; the override skips and retries.

## Languages

- gettext domain `imperator-layouts`, Spanish catalog in `po/es.po`. Extension catalogs are in `translations/<uuid>/` and compiled
  into each extension's `locale/`. The RPM's Spanish files carry no `%lang` tag so they install whatever the system language is.
  The `imperator-layout` CLI messages stay English (technician tool).
