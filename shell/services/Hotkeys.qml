pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Hotkey table (config/hotkeys.json).
// Ownership: entries with owner "user" already exist in the user's own hyprland.lua and call the shell through
// `shell-switch msg <command>`; aptus only SHOWS them (and answers the command). Entries with owner "aptus" are the
// new ones; they are written to binds.generated.lua, which the user's hyprland.lua loads.
// Signatures only. Bodies come in phase 7.
Singleton {
    property var bindings            // list of HotkeyBinding
    property var conflicts           // list of lists of binding ids that share a key

    Process {
        id: reload
        running: false
        // TODO(phase 7): `hyprctl reload` after a changed generated file; the watchdog covers a wrong binding.
    }

    // Read config/hotkeys.json plus the user's changes.
    function load(): var {
        throw new Error("not implemented")
    }

    // Empty string when valid, otherwise the reason.
    function validate(binding: var): string {
        if (!binding) throw new Error("invariant: Hotkeys.validate: no binding")
        throw new Error("not implemented")
    }

    function findConflicts(bindings: var): var {
        if (!Array.isArray(bindings)) throw new Error("invariant: Hotkeys.findConflicts: bindings must be an array")
        // TODO(phase 7): compare ALL entries (owner user and aptus) so a new key never hides one of the user's.
        throw new Error("not implemented")
    }

    // Lua text for the entries with owner "aptus": hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd(shell .. " launcher-open web")).
    function generateHyprlandLua(bindings: var): string {
        if (!Array.isArray(bindings)) throw new Error("invariant: Hotkeys.generateHyprlandLua: bindings must be an array")
        if (bindings.some(b => /suspend|hibernate/i.test(b.command || ""))) throw new Error("invariant: Hotkeys.generateHyprlandLua: a binding triggers suspend or hibernate")
        // TODO(phase 7): hl.bind(keys, hl.dsp.exec_cmd(<shell-switch msg> .. " " .. command), { locked, repeating }); hardware keys stay with the user's file.
        throw new Error("not implemented")
    }

    function writeHyprlandLua(bindings: var): void {
        if (!Array.isArray(bindings)) throw new Error("invariant: Hotkeys.writeHyprlandLua: bindings must be an array")
        if (bindings.some(b => /suspend|hibernate/i.test(b.command || ""))) throw new Error("invariant: Hotkeys.writeHyprlandLua: a binding triggers suspend or hibernate")
        throw new Error("not implemented")
    }

    function reloadHyprland(): void {
        // TODO(phase 7): used by the settings apply step.
        throw new Error("not implemented")
    }
}
