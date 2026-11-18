/*
 * Imperator panel order: macOS-style top panel (Activities and clock on the right).
 *
 * Derived from "Move activities and clock" (zorin-hide-activities-move-clock, version 2, shipped in
 * Zorin OS 18; that package's copyright file lists Ron M Yorston, 2011-2017, GPL-2.0-or-later, and the
 * extension descends from Frippery Move Clock). Change: GNOME rebuilds the panel on every session-mode
 * update (lock, unlock) and puts both items back in their default boxes, so the placement is re-applied
 * after each rebuild instead of only once at enable().
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of
 * the GNU General Public License as published by the Free Software Foundation, either version 2
 * of the License, or (at your option) any later version.
 */

import GLib from 'gi://GLib';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class ImperatorPanelOrderExtension extends Extension {
    enable() {
        this._idleId = 0;
        this._apply();
        // The panel's own 'updated' handler was connected first, so by the time ours runs the
        // panel has already moved the items back; defer one idle so we always go last.
        Main.sessionMode.connectObject('updated', () => this._queueApply(), this);
    }

    disable() {
        Main.sessionMode.disconnectObject(this);
        if (this._idleId) {
            GLib.source_remove(this._idleId);
            this._idleId = 0;
        }
        this._restore();
    }

    _queueApply() {
        if (this._idleId)
            return;
        this._idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
            this._idleId = 0;
            this._apply();
            return GLib.SOURCE_REMOVE;
        });
    }

    _item(role) {
        return Main.panel.statusArea?.[role]?.container ?? null;
    }

    _apply() {
        const {_leftBox: leftBox, _centerBox: centerBox, _rightBox: rightBox} = Main.panel;
        const panel = Main.sessionMode.panel;

        // Activities: first item of the right box. Only when this session mode shows it on the left.
        const activities = panel.left.includes('activities') ? this._item('activities') : null;
        if (activities && activities.get_parent() === leftBox) {
            leftBox.remove_child(activities);
            rightBox.insert_child_at_index(activities, 0);
        }

        // Clock: last item of the right box. Only when this session mode shows it in the center.
        const dateMenu = panel.center.includes('dateMenu') ? this._item('dateMenu') : null;
        if (dateMenu && dateMenu.get_parent() === centerBox) {
            centerBox.remove_child(dateMenu);
            rightBox.add_child(dateMenu);
        }
    }

    _restore() {
        const {_leftBox: leftBox, _centerBox: centerBox, _rightBox: rightBox} = Main.panel;

        const dateMenu = this._item('dateMenu');
        if (dateMenu && dateMenu.get_parent() === rightBox) {
            rightBox.remove_child(dateMenu);
            centerBox.add_child(dateMenu);
        }

        const activities = this._item('activities');
        if (activities && activities.get_parent() === rightBox) {
            rightBox.remove_child(activities);
            leftBox.insert_child_at_index(activities, 0);
        }
    }
}
