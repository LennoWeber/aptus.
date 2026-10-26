import QtQuick
import Quickshell
import Quickshell.Io
import qs.models
import qs.theme

// Light or dark for the shell and the apps (setting appearance.colorMode: light | dark | auto).
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

    property bool firstRun: true               // the first repaint (start-up) only paints when the apps are not in this mode yet

    Process {
        id: themeApps
        stderr: StdioCollector { id: appsErrors }
        onExited: (code, status) => root.onAppsExited(code)
    }

    Timer {
        id: debounce
        interval: root.debounceMs
        onTriggered: root.repaintApps()
    }

    Connections {
        target: root.appSettings
        function onValueChanged(path: string): void {
            if (path === "" || path === "appearance.colorMode") root.onSettingChanged(path)
        }
    }

    Connections {
        target: root.nightLight
        function onEnabledChanged(): void { root.onNightLightChanged() }
    }

    // The mode of the setting as an Enums.ColorMode; -1 for a name that is not light, dark or auto.
    function modeFromName(name: string): int {
        const modes = { light: Enums.ColorMode.Light, dark: Enums.ColorMode.Dark, auto: Enums.ColorMode.Auto }
        return modes[name] ?? -1
    }

    // The setting value of an Enums.ColorMode: "light", "dark" or "auto".
    function nameFromMode(m: int): string {
        if (!(m >= Enums.ColorMode.Light && m <= Enums.ColorMode.Auto)) throw new Error("invariant: ColorModeState.nameFromMode: unknown mode")
        return ["light", "dark", "auto"][m]
    }

    // Whether the mode `m` is dark right now (Auto follows nightLight.enabled).
    function resolve(m: int): bool {
        if (!(m >= Enums.ColorMode.Light && m <= Enums.ColorMode.Auto)) throw new Error("invariant: ColorModeState.resolve: unknown mode")
        if (!nightLight) throw new Error("invariant: ColorModeState.resolve: nightLight not set")
        return m === Enums.ColorMode.Dark || (m === Enums.ColorMode.Auto && nightLight.enabled === true)
    }

    // Start-up: read the setting, set the shell to it without a fade, repaint the apps only if the state differs.
    function start(): void {
        if (!appSettings || !nightLight) throw new Error("invariant: ColorModeState.start: appSettings and nightLight must be set")
        mode = appSettings.colorMode
        dark = resolve(mode)
        Tokens.colorModeFade = false
        applyShell()
        Tokens.colorModeFade = true
        repaintApps()
    }

    // Take the setting and the night light into account: when what is in effect changes, move the shell and repaint the apps.
    function update(): void {
        mode = appSettings.colorMode
        const now = resolve(mode)
        if (now === dark) return
        dark = now
        applyShell()
        debounce.restart()
    }

    // The setting changed (settings app, restore): read it again. `path` is "" when everything was restored.
    function onSettingChanged(path: string): void {
        update()
    }

    // The night light switched on or off: matters only in Auto.
    function onNightLightChanged(): void {
        if (mode === Enums.ColorMode.Auto) update()
    }

    // Choose a mode: write the setting; valueChanged then switches the shell and repaints the apps.
    function setMode(m: int): void {
        if (!(m >= Enums.ColorMode.Light && m <= Enums.ColorMode.Auto)) throw new Error("invariant: ColorModeState.setMode: unknown mode")
        if (!appSettings) throw new Error("invariant: ColorModeState.setMode: appSettings not set")
        appSettings.set("appearance.colorMode", nameFromMode(m))
        appSettings.writeUserConfig()     // so the choice survives a restart
    }

    // Light <-> dark by hand (Super+T); Auto becomes the opposite of what is in effect.
    function toggle(): void {
        setMode(dark ? Enums.ColorMode.Light : Enums.ColorMode.Dark)
    }

    // Move Tokens to the resolved mode.
    function applyShell(): void {
        if (!Tokens.palette) {
            console.warn("aptus: colour mode: tokens not loaded, the shell keeps its built-in colours")
            return
        }
        Tokens.darkAmount = dark ? 1 : 0
    }

    // The command line of the repaint for the mode in effect: aptus-theme-apps --mode <light|dark> --all --quiet.
    function appsCommand(isDark: bool): var {
        return [Tokens.rootDir + "/bin/aptus-theme-apps", "--mode", isDark ? "dark" : "light", "--all", "--quiet"]
    }

    // Run aptus-theme-apps for the resolved mode in the background (one run at a time, the last request wins).
    function repaintApps(): void {
        if (themeApps.running) {
            pending = true
            return
        }
        const command = appsCommand(dark)
        if (firstRun) command.push("--if-changed")
        firstRun = false
        applying = true
        themeApps.command = command
        themeApps.running = true
    }

    // The repaint finished: reset `applying`, keep `applyError` on a failure, start the pending run if there is one.
    function onAppsExited(code: int): void {
        applying = false
        if (code === 0) {
            applyError = ""
        } else {
            applyError = "aptus-theme-apps exited with " + code
            console.warn("aptus: " + applyError + ": " + appsErrors.text.trim())
        }
        if (pending) {
            pending = false
            repaintApps()
        }
    }
}
