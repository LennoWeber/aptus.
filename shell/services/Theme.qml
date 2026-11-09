pragma Singleton
// Theme: mode, accent, glass, auto schedule, render requests.
// Owner: S1 (mode, accent, glass via Config), S2 (aptus-theme apply, the auto schedule).
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // JSON summary of the last aptus-theme apply (S2; lib/aptus/theme/apply.py Report)
    property string lastApply: ""
    property bool applying: false
    // Target id → why, from the last apply's "failed" (the shell toasts only these).
    property var failed: ({})
    // The theme generation the last apply produced (0: none yet).
    property int generation: 0
    // The resolve inputs of the last request, as JSON (lib/aptus/theme/inputs.py Inputs).
    property string _pendingInputs: ""

    // S1: each setter writes Config (appearance.*), which re-resolves Tokens; S2 adds aptus-theme
    // apply on top (the app slots of 08 §5). Each returns "" or why Config refused the value.
    // appearance.mode: "dark" | "light" | "auto".
    function setMode(mode: string): string { return _set("appearance.mode", mode); }
    // Light ↔ dark, always explicit (Super+T): from `auto` it leaves auto for the opposite of now.
    function toggleMode(): string { return _set("appearance.mode", Tokens.mode === "dark" ? "light" : "dark"); }
    // appearance.accent: one of the six or "wallpaper".
    function setAccent(name: string): string { return _set("appearance.accent", name); }
    function setGlass(on: bool): string { return _set("appearance.glass", on); }

    // Ask for an `aptus-theme apply` with the current resolution: debounced 250 ms, started after
    // the shell's own crossfade (08 §6), one run at a time (a request during a run runs after it).
    function requestApply(): void {
        // phase 7
    }
    // The --inputs JSON for aptus-theme (lib/aptus/theme/inputs.py to_dict) from Tokens and Config.
    function _inputs(): var {
        return ({});
    }
    // Parse the JSON report on stdout into lastApply, failed and generation; warn for failures.
    function _applied(stdout: string, exitCode: int): void {
        // phase 7
    }

    function _set(key: string, value: var): string {
        const why = Config.set(key, value);
        if (why) Log.warn("service.theme", key + " = " + JSON.stringify(value) + " refused: " + why);
        else Log.info("service.theme", key + " = " + JSON.stringify(value));
        return why;
    }
}
