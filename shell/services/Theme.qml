pragma Singleton
// Theme: mode, accent, glass, auto schedule, render requests.
// Owner: S1 (mode, accent, glass via Config), S2 (aptus-theme apply). Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): setMode/toggleMode/setAccent/setGlass write Config (appearance.*), which
    //   re-resolves Tokens; aptus-theme apply arrives with S2.

    // JSON summary of the last aptus-theme apply
    property string lastApply: ""
    property bool applying: false

    // appearance.mode: "dark" | "light" | "auto".
    function setMode(mode: string): void { throw new Error("Theme.setMode: not implemented"); }
    // Light ↔ dark, always explicit (Super+T).
    function toggleMode(): void { throw new Error("Theme.toggleMode: not implemented"); }
    // appearance.accent: one of the six or "wallpaper".
    function setAccent(name: string): void { throw new Error("Theme.setAccent: not implemented"); }
    function setGlass(on: bool): void { throw new Error("Theme.setGlass: not implemented"); }
}
