// Loads a light dock stylesheet unless the system color scheme is 'prefer-dark'.
// Light Style forces the shell's session default to 'prefer-light', so 'default' (what
// Settings > Appearance stores for Light) shows a light shell; only 'prefer-dark' is dark.
// The top panel keeps the theme's own color, with a transparency preset only its alpha is set on top of it. Exception: the macOS layout's
// light-panel switch tints it with the dock's light color (light mode, glass off) so bar and dock match at every preset.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class ImperatorDockTheme extends Extension {
    enable() {
        this._settings = new Gio.Settings({schema_id: 'org.gnome.desktop.interface'});
        this._ext = this.getSettings();
        this._panelIdle = 0;
        this._ext.connectObject('changed::panel-opacity', () => this._queuePanel(), 'changed::light-panel', () => this._queuePanel(), this);
        this._ext.connectObject('changed::glass', () => { this._reloadSheets(); this._queuePanel(); }, this);
        St.ThemeContext.get_for_stage(global.stage).connectObject('changed', () => this._queuePanel(), this);
        Main.sessionMode.connectObject('updated', () => this._queuePanel(), this);
        Main.overview.connectObject('showing', () => this._clearPanel(), 'hidden', () => this._queuePanel(), this);
        this._queuePanel();
        this._file = this.dir.get_child('light.css');
        this._glassFile = this.dir.get_child('glass.css');
        this._glassDarkFile = this.dir.get_child('glass-dark.css');
        this._glassDark = false;
        this._loaded = false;
        this._glassLoaded = false;
        this._id = this._settings.connect('changed::color-scheme', () => this._sync());
        this._sync();
        Main.overview.connectObject('shown', () => this._probeReal('overview'), this);
        this._timeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 6, () => {
            this._timeoutId = 0;
            this._probeReal('startup');
            return GLib.SOURCE_REMOVE;
        });
    }

    disable() {
        Main.overview.disconnectObject(this);
        Main.sessionMode.disconnectObject(this);
        St.ThemeContext.get_for_stage(global.stage).disconnectObject(this);
        this._ext.disconnectObject(this);
        if (this._panelIdle) {
            GLib.source_remove(this._panelIdle);
            this._panelIdle = 0;
        }
        this._clearPanel();
        this._ext = null;
        if (this._timeoutId) {
            GLib.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }
        if (this._id) {
            this._settings.disconnect(this._id);
            this._id = 0;
        }
        this._unloadGlass();
        this._unload();
        this._settings = null;
        this._file = null;
        this._glassFile = null;
        this._glassDarkFile = null;
    }

    _queuePanel() {
        if (this._panelIdle)
            return;
        this._panelIdle = GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
            this._panelIdle = 0;
            this._applyPanel();
            return GLib.SOURCE_REMOVE;
        });
    }

    // Back to the stock look: no inline style, corner pieces visible.
    _clearPanel() {
        Main.panel.set_style(null);
        Main.panel.remove_style_class_name('imperator-light-panel');
        for (const corner of [Main.panel._leftCorner, Main.panel._rightCorner])
            corner?.show();
    }

    // Reads the theme's own panel color, then sets only the alpha. Left alone (stock) when no preset is chosen, when it is
    // 1.0, in the overview and on the lock/login screens. The glass switch forces alpha 0.
    _applyPanel() {
        try {
            this._clearPanel();
            const glass = this._ext.get_boolean('glass');
            const light = !glass && this._loaded && this._ext.get_boolean('light-panel');
            let a = glass ? 0 : this._ext.get_double('panel-opacity');
            if (light && a < 0)
                a = 1;
            if (a < 0 || (a >= 1 && !light) || Main.overview.visible || Main.sessionMode.currentMode !== 'user')
                return;
            if (light) {
                // Same light color as the dock (light.css), dark text via the style class.
                Main.panel.add_style_class_name('imperator-light-panel');
                Main.panel.set_style(`background-color: rgba(246, 246, 246, ${a});`);
                for (const corner of [Main.panel._leftCorner, Main.panel._rightCorner])
                    corner?.hide();
                console.log(`imperator-dock-theme: light top panel opacity ${a}`);
                return;
            }
            const c = Main.panel.get_theme_node().get_background_color();
            Main.panel.set_style(`background-color: rgba(${c.red}, ${c.green}, ${c.blue}, ${a});`);
            // The rounded corner pieces are painted black and would show as dark wedges on a translucent panel.
            for (const corner of [Main.panel._leftCorner, Main.panel._rightCorner])
                corner?.hide();
            console.log(`imperator-dock-theme: top panel opacity ${a} (theme color ${c.red},${c.green},${c.blue})`);
        } catch (e) {
            console.error(`imperator-dock-theme: panel opacity failed: ${e}`);
        }
    }

    _theme() {
        return St.ThemeContext.get_for_stage(global.stage).get_theme();
    }

    // glass.css goes on top of light.css, so it is (re)loaded after it every time.
    _loadGlass() {
        if (this._glassLoaded || !this._ext.get_boolean('glass'))
            return;
        try {
            this._theme().load_stylesheet(this._glassFile);
            this._glassLoaded = true;
            // Dark scheme: glass-dark.css on top turns the pale tints into dark ones.
            this._glassDark = this._settings.get_string('color-scheme') === 'prefer-dark';
            if (this._glassDark)
                this._theme().load_stylesheet(this._glassDarkFile);
        } catch (e) {
            console.error(`imperator-dock-theme: failed to load glass stylesheet: ${e}`);
        }
    }

    _unloadGlass() {
        if (!this._glassLoaded)
            return;
        if (this._glassDark)
            this._theme().unload_stylesheet(this._glassDarkFile);
        this._theme().unload_stylesheet(this._glassFile);
        this._glassLoaded = false;
        this._glassDark = false;
    }

    _reloadSheets() {
        this._unloadGlass();
        this._loadGlass();
    }

    _sync() {
        const light = this._settings.get_string('color-scheme') !== 'prefer-dark';
        if (this._glassLoaded && this._glassDark === light)
            this._unloadGlass();
        if (light && !this._loaded) {
            this._unloadGlass();
            try {
                this._theme().load_stylesheet(this._file);
                this._loaded = true;
                console.log(`imperator-dock-theme: loaded ${this._file.get_path()}`);
                this._probe();
            } catch (e) {
                console.error(`imperator-dock-theme: failed to load stylesheet: ${e}`);
            }
        } else if (!light) {
            this._unload();
        }
        this._loadGlass();
        this._queuePanel();
    }

    _findEntries(actor, out) {
        if (actor instanceof St.Entry && actor.has_style_class_name('search-entry'))
            out.push(actor);
        for (const child of actor.get_children())
            this._findEntries(child, out);
    }

    // Logs the computed background of every real search box (overview) and where it sits.
    _probeReal(tag) {
        try {
            const entries = [];
            this._findEntries(global.stage, entries);
            for (const e of entries) {
                const c = e.get_theme_node().get_background_color();
                const chain = [];
                for (let a = e, i = 0; a && i < 5; a = a.get_parent(), i++)
                    chain.push(`${a.constructor.name}.${a.style_class ?? ''}`);
                console.log(`imperator-dock-theme: [${tag}] entry bg=${c.red},${c.green},${c.blue} pseudo='${e.get_style_pseudo_class()}' mapped=${e.mapped} chain=${chain.join(' < ')}`);
            }
            console.log(`imperator-dock-theme: [${tag}] ${entries.length} search entries`);
        } catch (e) {
            console.error(`imperator-dock-theme: probeReal failed: ${e}`);
        }
    }

    // Logs the computed color of a plain search entry so a wrong override shows up in the journal.
    _probe() {
        try {
            const entry = new St.Entry({style_class: 'search-entry'});
            Main.uiGroup.add_child(entry);
            const c = entry.get_theme_node().get_background_color();
            console.log(`imperator-dock-theme: probe search-entry bg=${c.red},${c.green},${c.blue}`);
            Main.uiGroup.remove_child(entry);
            entry.destroy();
        } catch (e) {
            console.error(`imperator-dock-theme: probe failed: ${e}`);
        }
    }

    _unload() {
        if (!this._loaded)
            return;
        this._theme().unload_stylesheet(this._file);
        this._loaded = false;
    }
}
