import QtQuick
import Quickshell
import Quickshell.Io
import qs.models

// Light or dark for the shell and the apps (setting appearance.colorMode: light | dark | auto). Structure only.
// `mode` is the chosen value, `dark` what is in effect (auto is dark while the night light runs); Tokens.darkAmount
// follows `dark` (0 or 1) with Tokens.colorModeMs. After a change the apps are repainted by
// `aptus-theme-apps --mode <light|dark> --all` in the background; the shell itself changes first.
Scope {
    id: root

    property var appSettings    // AppSettings: reads and writes appearance.colorMode
    property var nightLight     // NightLightState: decides `auto`

    property int mode: Enums.ColorMode.Light
    property bool dark: false
    property bool applying: false
    property bool pending: false               // a repaint was asked for while one was running
    property string applyError: ""
    property int debounceMs: 250               // several presses repaint the apps once

    // TODO(phase 7, colour mode): command = appsCommand(dark), onExited -> onAppsExited(exitCode); failures only logged.
    Process {
        id: themeApps
    }

    // TODO(phase 7, colour mode): onTriggered -> run the repaint (or set pending if one runs).
    Timer {
        id: debounce
        interval: root.debounceMs
    }

    // TODO(phase 7, colour mode): Connections on appSettings.valueChanged(path) -> onSettingChanged, on nightLight.enabledChanged -> onNightLightChanged; settings are loaded before start().


    // The mode of the setting as an Enums.ColorMode; -1 for a name that is not light, dark or auto.
    function modeFromName(name: string): int {
        throw new Error("not implemented")
    }

    // The setting value of an Enums.ColorMode: "light", "dark" or "auto".
    function nameFromMode(m: int): string {
        throw new Error("not implemented")
    }

    // Whether the mode `m` is dark right now (Auto follows nightLight.enabled).
    function resolve(m: int): bool {
        throw new Error("not implemented")
    }

    // Start-up: read the setting, set the shell to it without a fade, repaint the apps only if the state differs.
    function start(): void {
        throw new Error("not implemented")
    }

    // The setting changed (settings app, restore): read it again. `path` is "" when everything was restored.
    function onSettingChanged(path: string): void {
        throw new Error("not implemented")
    }

    // The night light switched on or off: matters only in Auto.
    function onNightLightChanged(): void {
        throw new Error("not implemented")
    }

    // Choose a mode: write the setting, switch the shell, repaint the apps.
    function setMode(m: int): void {
        throw new Error("not implemented")
    }

    // Light <-> dark by hand (Super+T); Auto becomes the opposite of what is in effect.
    function toggle(): void {
        throw new Error("not implemented")
    }

    // Move Tokens to the resolved mode.
    function applyShell(): void {
        throw new Error("not implemented")
    }

    // The command line of the repaint for the mode in effect: aptus-theme-apps --mode <light|dark> --all --quiet.
    function appsCommand(isDark: bool): var {
        throw new Error("not implemented")
    }

    // Run aptus-theme-apps for the resolved mode in the background (one run at a time, the last request wins).
    function repaintApps(): void {
        throw new Error("not implemented")
    }

    // The repaint finished: reset `applying`, keep `applyError` on a failure, start the pending run if there is one.
    function onAppsExited(code: int): void {
        throw new Error("not implemented")
    }
}
