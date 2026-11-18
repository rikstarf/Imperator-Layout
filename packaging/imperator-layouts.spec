# Imperator desktop layouts: GNOME extensions, layout profiles and the layout switcher, as one self-contained
# noarch package (no network needed to install it; see PACKAGING.md). Build with tools/build-rpm.sh.
%global debug_package %{nil}
%global __brp_mangle_shebangs %{nil}
%global _binary_payload w9.gzdio
%global extdir %{_datadir}/gnome-shell/extensions

Name:           imperator-layouts
Version:        1.5.2
Release:        1
Summary:        Imperator desktop layouts (macOS-like, Windows 11-like, ChromeOS-like) for GNOME
License:        GPL-2.0-or-later AND GPL-2.0-only AND GPL-3.0-or-later
URL:            https://github.com/rikstarf/Imperator-Layout
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  glib2-devel
BuildRequires:  gettext
Requires:       gnome-shell >= 51
Requires:       gnome-shell < 52
Requires:       dconf
Requires:       glib2
Requires:       gjs
Requires:       libadwaita
# Fedora's own packages of extensions we bundle (same directories under /usr/share/gnome-shell/extensions): refuse cleanly
# instead of failing on a file conflict.
Conflicts:      gnome-shell-extension-appindicator
Conflicts:      gnome-shell-extension-blur-my-shell
Conflicts:      gnome-shell-extension-dash-to-dock
Conflicts:      gnome-shell-extension-dash-to-panel
Conflicts:      gnome-shell-extension-light-style
Conflicts:      gnome-shell-extension-logo-menu

%description
Vanilla GNOME plus three desktop layouts (and an optional glass effect) (macOS-like, Windows 11-like, ChromeOS-like) built from upstream GPL extensions (Dash to
Dock, Dash to Panel, ArcMenu, Logo Menu, AppMenu, AppIndicator, Light Style) and two Imperator extensions, with the
imperator-layout command and a small picker window (English and Spanish) to switch between them and to choose a
transparency preset. Everything is bundled, so the package
installs from a local file without network access. Extensions are installed system-wide; each user enables the layout
they want (a site default can be applied at first login, see /etc/imperator-layouts/default-layout).

%prep
%setup -q

%build
tools/stage-extensions.sh staged
tools/build-locale.sh locale-staged

%install
install -d %{buildroot}%{extdir}
for d in staged/*/; do
  uuid="$(basename "$d")"
  cp -a "$d" "%{buildroot}%{extdir}/$uuid"
  echo "%{extdir}/$uuid" >> extensions.list
done
find %{buildroot}%{extdir} -type d -exec chmod 0755 {} +
find %{buildroot}%{extdir} -type f -exec chmod 0644 {} +

install -d %{buildroot}%{_datadir}/imperator-layouts
cp -a layouts %{buildroot}%{_datadir}/imperator-layouts/layouts
find %{buildroot}%{_datadir}/imperator-layouts/layouts -type f -exec chmod 0644 {} +
install -m 0755 imperator-layout %{buildroot}%{_datadir}/imperator-layouts/imperator-layout
echo "%{version}" > %{buildroot}%{_datadir}/imperator-layouts/VERSION
install -m 0755 imperator-layout-ui %{buildroot}%{_datadir}/imperator-layouts/imperator-layout-ui
install -d %{buildroot}%{_bindir}
ln -s ../share/imperator-layouts/imperator-layout %{buildroot}%{_bindir}/imperator-layout
ln -s ../share/imperator-layouts/imperator-layout-ui %{buildroot}%{_bindir}/imperator-layout-ui

install -d %{buildroot}%{_datadir}/locale
cp -a locale-staged/. %{buildroot}%{_datadir}/locale/

install -Dpm 0644 packaging/imperator-layouts.desktop %{buildroot}%{_datadir}/applications/imperator-layouts.desktop
install -Dpm 0644 packaging/imperator-layouts-firstrun.desktop %{buildroot}%{_sysconfdir}/xdg/autostart/imperator-layouts-firstrun.desktop
install -Dpm 0644 packaging/default-layout %{buildroot}%{_sysconfdir}/imperator-layouts/default-layout
install -Dpm 0644 packaging/imperator.repo %{buildroot}%{_sysconfdir}/yum.repos.d/imperator.repo
install -Dpm 0644 packaging/RPM-GPG-KEY-imperator %{buildroot}%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-imperator

%files -f extensions.list
%license LICENSE vendor/NOTICE.md vendor/COPYING
%doc README.md DESIGN.md PACKAGING.md
%{_bindir}/imperator-layout
%{_bindir}/imperator-layout-ui
%{_datadir}/imperator-layouts/
%{_datadir}/applications/imperator-layouts.desktop
%{_datadir}/locale/es/LC_MESSAGES/imperator-layouts.mo
%{_sysconfdir}/xdg/autostart/imperator-layouts-firstrun.desktop
%dir %{_sysconfdir}/imperator-layouts
%config(noreplace) %{_sysconfdir}/imperator-layouts/default-layout
%config(noreplace) %{_sysconfdir}/yum.repos.d/imperator.repo
%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-imperator

%changelog
* Wed Nov 18 2026 Imperator Solutions <noreply@imperator.local> - 1.5.2-1
- Glass: menus, the Apple menu, switchers and the calendar and notifications popover are clear glass with white text in both color schemes
- Glass: the control panel is clear again in light mode (Blur My Shell no longer paints its solid theme fill on it)
- Glass: slightly lighter white veil in light mode so white text stays readable
- `glass on|off` waits for Files to exit before returning

* Wed Nov 18 2026 Imperator Solutions <noreply@imperator.local> - 1.5.1-1
- Glass re-tuned toward the macOS Tahoe look: much wider blur (radius 150 for dock, top bar, popups and overview, 200 for windows) with boosted saturation so the wallpaper's colors smear through, and a lighter white veil in light mode
- Dock and popups use Blur My Shell's transparent style so the pipeline alone tints them (no extra 65% white fill)

* Wed Nov 18 2026 Imperator Solutions <noreply@imperator.local> - 1.5.0-1
- Glass is now exclusive to the macOS layout: other layouts refuse `glass on`, the picker greys the switch out, and switching away from macOS turns the effect off (the choice is remembered for when macOS is applied again)
- Transparency presets are locked while glass is on (CLI refuses, picker greys the group out)
- Wider blur: shared pipelines radius 80 (was 30), application windows radius 180 (was 90)

* Wed Nov 18 2026 Imperator Solutions <noreply@imperator.local> - 1.4.2-1
- Glass: application windows blur harder (radius 90 instead of 30)
- Glass: dock, popups and every other blurred surface follow the light/dark scheme (automatic pipeline and style); dark mode no longer gets the white tint or white solid control panel and calendar
- Glass: new glass-dark.css for the dark scheme (dark dock and control panel tints)
- Glass: workspace pill is white on the see-through top bar in the light theme

* Wed Nov 18 2026 Imperator Solutions <noreply@imperator.local> - 1.4.1-1
- Picker: Updates row that opens GNOME Software's updates page (English and Spanish)
- README: supported systems
- Conflicts with Fedora's own packages of the bundled extensions (appindicator, blur-my-shell, dash-to-dock, dash-to-panel, light-style, logo-menu)

* Wed Nov 18 2026 Imperator Solutions <noreply@imperator.local> - 1.4.0-1
- Updates from a signed RPM repo: ships imperator.repo and the release public key, so rpm-ostree upgrade / dnf upgrade pick up new releases
- Requires gnome-shell >= 51 and < 52: refuses an untested GNOME major until a vetted release is published
- Works on Silverblue (rpm-ostree) and regular Fedora Workstation (dnf)

* Wed Nov 18 2026 Imperator Solutions <noreply@imperator.local> - 1.3.3-1
- macOS layout: light top bar tinted like the dock (light mode, glass off) so bar and dock match at every preset

* Wed Nov 18 2026 Imperator Solutions <noreply@imperator.local> - 1.3.2-1
- Toggling glass quits Files (it stays resident and never re-reads gtk.css)

* Wed Nov 18 2026 Imperator Solutions <noreply@imperator.local> - 1.3.1-1
- Glass: windows use the static blur (blurred wallpaper under each window); the switch now says that open apps must be reopened
  to change their window look.

* Tue Nov 17 2026 Imperator Solutions <noreply@imperator.local> - 1.3.0-1
- Upgrades: at login, a user who already has a layout is re-applied once when the package moves to a new release (MAJOR.MINOR), so
  new profile values reach them; their layout, glass switch and transparency preset are kept. Hotfix (patch) updates do nothing.

* Tue Nov 17 2026 Imperator Solutions <noreply@imperator.local> - 1.2.4-1
- Glass: window backgrounds are translucent, text and icons are not. `glass on` writes a managed block into the user's gtk-4.0 and gtk-3.0
  gtk.css (removed by `glass off` and by the vanilla layout); the window itself stays opaque (Blur My Shell opacity 255).

* Tue Nov 17 2026 Imperator Solutions <noreply@imperator.local> - 1.2.3-1
- Glass: the control panel (quick settings) gets the dock's look without blur; windows made clearer.

* Tue Nov 17 2026 Imperator Solutions <noreply@imperator.local> - 1.2.2-1
- ArcMenu no longer fails with "this.panel is undefined" when Dash to Panel is still building its panels (override of its extension.js).

* Tue Nov 17 2026 Imperator Solutions <noreply@imperator.local> - 1.2.1-1
- Glass goes toward white (Blur My Shell light pipeline), top-bar text is white, every window is blurred.
- "Theme default" transparency is gone; "solid" is the default for all three layouts. Glass owns the dock/taskbar opacity while on.

* Tue Nov 17 2026 Imperator Solutions <noreply@imperator.local> - 1.2.0-1
- Glass effect: one switch (imperator-layout glass on|off, also in the picker) that enables Blur My Shell for the dock or taskbar,
  popups and the overview, and makes the top bar see-through. Vendors Blur My Shell v78 (GPL-3.0-or-later).
- The "glass" transparency preset is now called "clear".

* Tue Nov 17 2026 Imperator Solutions <noreply@imperator.local> - 1.1.0-1
- New "GNOME (default)" layout: vanilla GNOME, none of our extensions, our settings reset. No site default now means vanilla.
- Transparency presets for the dock, the taskbar and the stock top panel; opacity only, the color stays the theme's.
- Language files are not tagged %lang, so they install whatever the system language or _install_langs is.
- The picker is translated (English, Spanish); Spanish catalogs also restored for Logo Menu, Dash to Dock and Dash to Panel,
  and a Spanish catalog written for AppMenu. AppMenu's Window-menu check now recognizes a translated Window menu.

* Tue Nov 17 2026 Imperator Solutions <noreply@imperator.local> - 1.0.0-1
- First RPM: replaces the tarball installer and layer-packages.sh. AppIndicator and Light Style are bundled.
