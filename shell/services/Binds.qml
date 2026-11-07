pragma Singleton
// Binds: bind table, descriptions (hyprctl binds -j, known-binds.json).
// Owner: S8 (table, overrides); Settings › Keys (S10) uses its methods. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): until S8 fills this service, each action method logs "not available yet"
    //   (category service.<name>) instead of throwing (phase-1 decision 6).

    // [{ id, chord, defaultChord, group, description, hidden: bool, aptus: bool, changed: bool,
    //    dispatcher, arg }] — aptus binds carry their id from the description, others are described
    //    from shell/config/known-binds.json
    property var binds: []
    // The bind using a chord, or null (conflict check of settings.md §6).
    function conflict(chord: string): var { throw new Error("Binds.conflict: not implemented"); }
    // Write binds.local.lua (atomic) and reload Hyprland; chord "" disables the bind.
    function setOverride(id: string, chord: string): void { throw new Error("Binds.setOverride: not implemented"); }
    function resetOverride(id: string): void { throw new Error("Binds.resetOverride: not implemented"); }
    // Run a bind's dispatcher (Spotlight Keys scope, the Keys sheet's Enter).
    function perform(id: string): void { throw new Error("Binds.perform: not implemented"); }
}
