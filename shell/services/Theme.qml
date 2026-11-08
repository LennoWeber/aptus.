pragma Singleton
// Theme: mode, accent, glass, auto schedule, render requests.
// Owner: S1 (mode, accent, glass via Config), S2 (aptus-theme apply, the auto schedule).
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // JSON summary of the last aptus-theme apply (S2)
    property string lastApply: ""
    property bool applying: false

    // S1: each setter writes Config (appearance.*), which re-resolves Tokens; S2 adds aptus-theme
    // apply on top (the app slots of 08 §5).
    // appearance.mode: "dark" | "light" | "auto".
    function setMode(mode: string): void { _set("appearance.mode", mode); }
    // Light ↔ dark, always explicit (Super+T): from `auto` it leaves auto for the opposite of now.
    function toggleMode(): void { _set("appearance.mode", Tokens.mode === "dark" ? "light" : "dark"); }
    // appearance.accent: one of the six or "wallpaper".
    function setAccent(name: string): void { _set("appearance.accent", name); }
    function setGlass(on: bool): void { _set("appearance.glass", on); }

    function _set(key: string, value: var): void {
        const why = Config.set(key, value);
        if (why) Log.warn("service.theme", key + " = " + JSON.stringify(value) + " refused: " + why);
        else Log.info("service.theme", key + " = " + JSON.stringify(value));
    }
}
