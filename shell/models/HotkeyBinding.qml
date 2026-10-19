import QtQuick

// One shortcut as described in config/hotkeys.json.
QtObject {
    property string id
    property string label
    property var mods                // list of "SUPER", "SHIFT", "CTRL", "ALT"
    property string key
    property string action           // e.g. "launcher.open:web"
    property bool conflicting        // set when another binding uses the same combination

    // Readable combination, e.g. 'Super+D'.
    function combo(): string {
        if (!key) throw new Error("invariant: HotkeyBinding.combo: binding without a key")
        throw new Error("not implemented")
    }

    // One line for the generated Hyprland config.
    function toHyprlandBind(): string {
        if (!key) throw new Error("invariant: HotkeyBinding.toHyprlandBind: binding without a key")
        if (!mods || mods.length === 0) throw new Error("invariant: HotkeyBinding.toHyprlandBind: binding without a modifier")
        throw new Error("not implemented")
    }
}
