# Vendored extensions

Upstream extensions, included as released (ArcMenu, Dash to Panel, Dash to Dock, Logo Menu, AppMenu, AppIndicator, Light Style, Blur my Shell).
Licenses: Blur my Shell is GPL-3.0-or-later; ArcMenu, Dash to Panel, Dash to Dock, AppIndicator and Light Style are GPL-2+ (upstream READMEs, LICENSE files and source headers); Logo Menu ships a GPL-2.0 LICENSE file (no
per-file "or later" notice found); AppMenu is GPL-3.0-or-later (GPLv3 LICENSE file, README states "or later"). They are
included unmodified except for the trimmed and replaced files listed below; `install-layouts.sh` does not edit any metadata.

| Extension | Copyright (from package metadata / headers) |
|---|---|
| dash-to-panel v74 | 2016-2026 Jason DeRose and contributors (https://github.com/home-sweet-gnome/dash-to-panel); README: GPL-v2 or later. Upstream release built the way its Makefile does (src flattened, UI files, images, schema); Spanish catalog restored (see Translations below). Its source headers and README credit the Zorin OS Taskbar it descends from; that attribution stays |
| dash-to-dock v110 | 2012-2026 Michele Gaio and contributors (https://github.com/micheleg/dash-to-dock); README: GPL version 2 or later. Upstream release built from source: `stylesheet.css` compiled from `_stylesheet.scss` with Dart Sass, Spanish catalog restored (see Translations below) |
| logomenu 25.2 (`logomenu@aryan_k`) | Aryan Kaushik (https://github.com/Aryan20/Logomenu, commit 0afd438, a fork of Tofu Menu); GPL-2.0 per its LICENSE. Included with its `Resources/` (distro logos shown only in its icon picker); Spanish catalog restored (see Translations below) |
| blur-my-shell v78 (`blur-my-shell@aunetx`) | Aunetx and contributors (https://github.com/aunetx/blur-my-shell, tag v78, commit 66c7e7a); GPL-3.0-or-later (its README: "version 3 or later"; LICENSE is the GPLv3 text). Built the way its Makefile does (component stylesheets concatenated, gresource compiled, `version` removed from metadata); its preferences translations are not included |
| appmenu 5.7.1 (`appmenu@ChathurangaBW.github.io`) | ChathurangaBW (https://github.com/ChathurangaBW/AppMenu, commit edd9373, 2026-10-11); GPL-3.0-or-later. Runtime files only (no dist/ builds, QA docs, screenshot, po sources); includes its `icons/` (distro logos shown only in its icon picker). Pure GJS, no daemon; Dbusmenu typelib optional |
| appindicator v66 (`appindicatorsupport@rgcjonas.gmail.com`) | Ubuntu / AppIndicator contributors (https://github.com/ubuntu/gnome-shell-extension-appindicator, tag v66; see its AUTHORS.md); GPL-2.0-or-later per its source headers. Runtime files only (no tests, lint, tools, translations) |
| light-style 51.0 (`light-style@gnome-shell-extensions.gcampax.github.com`) | Florian Müllner and GNOME contributors (gnome-shell-extensions tag 51.0, https://gitlab.gnome.org/GNOME/gnome-shell-extensions); GPL-2.0-or-later per its SPDX header. `metadata.json` generated the way the upstream meson build does (Shell 51 only, no settings schema, which this extension does not have) |
| arcmenu 70.0 | ArcMenu Team (https://gitlab.com/arcmenu/ArcMenu); GPL v2 text in its LICENSE, the app's About page says "version 2 or later". Its README and About page mention that it started as a fork of the Zorin menu; that history stays |

`vendor/versions.tsv` records the version of each vendored extension for `tools/check-upstream.sh`; keep it in step with the table above.

The GPL-2.0 text is in `vendor/COPYING` (copied from ArcMenu's LICENSE; ArcMenu also keeps its own copy in its folder).

## Removed files

Logo files and sponsor branding of one downstream distribution that some upstream releases carry are not shipped (one file in
`dash-to-panel/img/`, one in `appmenu/icons/`, four in `logomenu/Resources/` including the `hicolor` copies). The upstream
attribution in license headers, READMEs and ArcMenu's About-page history is left alone.

## Translations (`translations/`, `po/`)

Spanish catalogs, compiled at build time into each extension's `locale/`: Logo Menu, Dash to Dock and Dash to Panel are the
upstream `po/es.po` files (same license and authors as the extension); the AppMenu and picker catalogs were written for this
project (AppMenu's under GPL-3.0-or-later like AppMenu, the picker's GPL-2.0-or-later). Upstream translation credits stay in
the `.po` headers.

## Modified files (overrides/)

Whole files that replace the vendored ones at install time; the vendored originals stay as released. Same license as the
originals.

- `arcmenu@arcmenu.com/search.js`: adds the owner argument GNOME 51 requires on one `connectObject` call.
- `dash-to-panel@jderose9.github.com/prefs.js` and `ui/SettingsAbout.ui`: drop the downstream distribution's "Sponsored and originally developed by" badge from the About page (the code that loaded its logo goes with it).
- `logomenu@aryan_k/constants.js`: removes the two downstream-distribution logo entries from the icon lists. They sit after index 16, so
  `menu-button-icon-image=16` is unaffected.
- `arcmenu@arcmenu.com/extension.js`: skips a Dash to Panel panel whose `.panel` object is not built yet and retries (up to 20 times, every 0.5 s) instead of failing with "this.panel is undefined" (see DESIGN.md).
- `appmenu@ChathurangaBW.github.io/icons.json`: removes the downstream distribution's entry (the last one).
- `appmenu@ChathurangaBW.github.io/menuManager.js`: the "has a Window menu" check also matches the translated word (one line; see DESIGN.md).

## Our own extensions (`extensions/`)

- `imperator-dock-theme`: written for this project.
- `imperator-panel-order`: derived from "Move activities and clock" (zorin-hide-activities-move-clock, version 2, from Zorin OS 18;
  its package copyright file lists Ron M Yorston 2011-2017, GPL-2.0-or-later; it descends from Frippery Move Clock).
  Change: the placement is re-applied after every panel rebuild (lock/unlock), which the original did not do.
  GPL-2.0-or-later; the derivation is stated in the file header.
