pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Hotkey table (config/hotkeys.json), shown in the settings. Entries with owner "user" are bound in the user's own
// hyprland.lua and call the shell through `shell-switch msg <command>`; owner "aptus" ones are in hypr/binds.generated.lua.
// The table is read-only: shortcuts are changed in those two files, so a wrong key can never lock anyone out.
Singleton {
    id: root

    property var bindings: []        // { id, label, mods, key, owner, ... }
    readonly property var conflicts: findConflicts(bindings)   // { bindingId: [labels of the others] }

    readonly property string rootDir: Quickshell.env("APTUS_ROOT") || Quickshell.shellPath("..")

    FileView {
        id: file
        path: root.rootDir + "/config/hotkeys.json"
        blockLoading: true
        Component.onCompleted: {
            try { root.bindings = JSON.parse(text()).hotkeys || [] } catch (e) { console.warn("aptus: hotkeys.json not readable: " + e) }
        }
    }

    // "Super + Shift + B".
    function combo(binding: var): string {
        const names = { SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt" }
        return (binding.mods || []).map(m => names[m] || m).concat([binding.key]).join(" + ")
    }

    // Bindings that share a key combination (all owners, so a new key never hides one of the user's).
    function findConflicts(list: var): var {
        const byCombo = {}
        for (const b of list || []) {
            const c = combo(b).toLowerCase()
            if (!(c in byCombo)) byCombo[c] = []
            byCombo[c].push(b)
        }
        const out = {}
        for (const c in byCombo) {
            const group = byCombo[c]
            if (group.length < 2) continue
            for (const b of group) out[b.id] = group.filter(o => o.id !== b.id).map(o => o.label)
        }
        return out
    }
}
