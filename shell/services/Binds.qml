pragma Singleton
// Binds: bind table, descriptions (hyprctl binds -j, known-binds.json).
// Owner: S8 (table, overrides); Settings › Keys (S10) uses its methods. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // [{ id, chord, defaultChord, group, description, hidden: bool, aptus: bool, changed: bool,
    //    dispatcher, arg }] — aptus binds carry their id from the description, others are described
    //    from shell/config/known-binds.json
    property var binds: []
    // The bind using a chord, or null (conflict check of settings.md §6).
    function conflict(chord: string): var { Log.info("service.binds", "conflict: not available yet"); return null; }
    // Write binds.local.lua (atomic) and reload Hyprland; chord "" disables the bind.
    function setOverride(id: string, chord: string): void { Log.info("service.binds", "setOverride: not available yet"); }
    function resetOverride(id: string): void { Log.info("service.binds", "resetOverride: not available yet"); }
    // Run a bind's dispatcher (Spotlight Keys scope, the Keys sheet's Enter).
    function perform(id: string): void { Log.info("service.binds", "perform: not available yet"); }
}
