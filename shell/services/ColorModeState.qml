import QtQuick
import Quickshell
import Quickshell.Io
import qs.models
import qs.theme

// The theme of the shell and the apps (setting appearance.theme). `chosen` is the setting, `resolved` the theme in effect
// (auto is light, or dark while the night light runs; wallpaper needs ThemeSource.palette); Tokens fades to it in
// Tokens.colorModeMs. After a change the apps are repainted by `aptus-theme-apps --theme <resolved> --all` in the
// background; the shell itself changes first.
Scope {
    id: root

    property var appSettings    // AppSettings: reads and writes appearance.theme
    property var nightLight     // NightLightState: decides `auto`

    property string chosen: "light"            // appearance.theme as set: light | dark | auto | ocean | forest | dusk | sand | sky | wallpaper
    property string resolved: "light"          // the theme in effect: `chosen`, or light/dark for auto, or the previous one while the wallpaper theme is not ready
    property string previewId: ""              // the theme the picker shows right now, "" when none (the shell shows it, the apps do not)
    property bool dark: false                  // the base of the theme showing is dark
    property bool applying: false
    property bool pending: false               // a repaint was asked for while one was running
    property string applyError: ""
    property int debounceMs: 250               // several presses repaint the apps once

    property bool firstRun: true               // the first repaint (start-up) only paints when the apps are not in this theme yet

    Process {
        id: themeApps
        stderr: StdioCollector { id: appsErrors }
        // qmllint disable signal-handler-parameters
        onExited: code => root.onAppsExited(code)
        // qmllint enable signal-handler-parameters
    }

    Timer {
        id: debounce
        interval: root.debounceMs
        onTriggered: root.repaintApps()
    }

    Connections {
        target: root.appSettings
        function onValueChanged(path: string): void {
            if (path === "" || path === "appearance.theme" || path === "appearance.wallpaperTone") root.onSettingChanged(path)
        }
    }

    Connections {
        target: root.nightLight
        function onEnabledChanged(): void { root.onNightLightChanged() }
    }

    Connections {
        target: ThemeSource
        function onChanged(): void { root.onWallpaperThemeChanged() }
    }

    // Whether `id` is a value of appearance.theme: light, dark, auto, wallpaper or one of the themes of tokens.json.
    function isValid(id: string): bool {
        return id === "auto" || Tokens.themeIds().indexOf(id) >= 0
    }

    // The values the picker steps through, in its order: Tokens.themeIds() (light, dark, the colour themes, wallpaper).
    function choices(): var {
        return Tokens.themeIds()
    }

    // The theme in effect for the setting value `chosen`: itself, light or dark for auto (dark while nightLight.enabled), and for
    // wallpaper the id "wallpaper" once ThemeSource.palette is there, else the theme that was showing.
    function resolve(chosen: string): string {
        if (!isValid(chosen)) throw new Error("invariant: ColorModeState.resolve: unknown theme " + chosen)
        if (!nightLight) throw new Error("invariant: ColorModeState.resolve: nightLight not set")
        if (chosen === "auto") return nightLight.enabled === true ? "dark" : "light"
        if (chosen === "wallpaper") return Tokens.themeColors("wallpaper") ? "wallpaper" : resolved
        return chosen
    }

    // The setting's value, or light when it is not a theme (a hand-edited file).
    function settingTheme(): string {
        if (!appSettings) throw new Error("invariant: ColorModeState.settingTheme: appSettings not set")
        const id = appSettings.theme
        if (isValid(id)) return id
        console.warn("aptus: appearance.theme '" + id + "' is not a theme, using light")
        return "light"
    }

    // Start-up: read the setting, set the shell to it without a fade, repaint the apps only if the state differs.
    function start(): void {
        if (!appSettings || !nightLight) throw new Error("invariant: ColorModeState.start: appSettings and nightLight must be set")
        if (!Tokens.palette) {
            console.warn("aptus: theme: tokens not loaded, the shell keeps its built-in colours")
            return
        }
        chosen = settingTheme()
        followWallpaperTheme()
        ThemeSource.read()
        if (ThemeSource.palette) Tokens.setCustomTheme(ThemeSource.palette)
        resolved = resolve(chosen)
        dark = Tokens.isDarkTheme(resolved)
        applyShell()
        repaintApps()
        if (chosen === "wallpaper") ThemeSource.refresh()
    }

    // The wallpaper theme is made only while it is the theme chosen (or previewed).
    function followWallpaperTheme(): void {
        if (!appSettings) throw new Error("invariant: ColorModeState.followWallpaperTheme: appSettings not set")
        ThemeSource.active = chosen === "wallpaper" || previewId === "wallpaper"
        ThemeSource.tone = appSettings.wallpaperTone
    }

    // Take the setting and the night light into account: when what is in effect changes, move the shell and repaint the apps.
    function update(): void {
        chosen = settingTheme()
        previewId = ""
        followWallpaperTheme()
        if (chosen === "wallpaper") ThemeSource.refresh()
        const now = resolve(chosen)
        if (now === resolved) return
        resolved = now
        dark = Tokens.isDarkTheme(resolved)
        applyShell()
        debounce.restart()
    }

    // The setting changed (settings app, restore): read it again. `path` is "" when everything was restored.
    function onSettingChanged(path: string): void {
        update()
    }

    // The night light switched on or off: matters only in Auto.
    function onNightLightChanged(): void {
        if (chosen === "auto") update()
    }

    // Choose a theme (a value of appearance.theme): write the setting; valueChanged then switches the shell and repaints the apps.
    function setTheme(id: string): void {
        if (!isValid(id)) throw new Error("invariant: ColorModeState.setTheme: unknown theme " + id)
        if (!appSettings) throw new Error("invariant: ColorModeState.setTheme: appSettings not set")
        appSettings.set("appearance.theme", id)
        appSettings.writeUserConfig()     // so the choice survives a restart
    }

    // Choose the theme `step` places after (or before, negative) the one in effect; wraps around. Used by Super+T in the picker.
    function next(step: int): void {
        if (!Number.isInteger(step) || step === 0) throw new Error("invariant: ColorModeState.next: step is a non-zero integer")
        const list = choices()
        const from = list.indexOf(previewId || resolved)
        setTheme(list[((from < 0 ? 0 : from) + step % list.length + list.length) % list.length])
    }

    // Show the theme `id` in the shell only (the picker's preview); the apps and the setting stay as they are.
    function preview(id: string): void {
        if (!appSettings) throw new Error("invariant: ColorModeState.preview: appSettings not set")
        if (!isValid(id) || id === "auto") throw new Error("invariant: ColorModeState.preview: not a theme " + id)
        previewId = id
        if (id === "wallpaper") {
            followWallpaperTheme()
            ThemeSource.refresh()
        }
        if (!Tokens.themeColors(id)) return        // the wallpaper theme is not made yet; it fades in when it is
        Tokens.setTheme(id, true)
        dark = Tokens.isDarkTheme(id)
    }

    // End the preview: back to the theme in effect (resolved).
    function cancelPreview(): void {
        if (previewId === "") return
        previewId = ""
        followWallpaperTheme()
        Tokens.setTheme(resolved, true)
        dark = Tokens.isDarkTheme(resolved)
    }

    // Keep the previewed theme: same as setTheme(previewId), then the preview ends.
    function commitPreview(): void {
        if (!appSettings) throw new Error("invariant: ColorModeState.commitPreview: appSettings not set")
        const id = previewId
        if (id === "") return
        setTheme(id)
        previewId = ""
    }

    // ThemeSource has a new palette (the wallpaper changed): when the wallpaper theme is chosen, fade to it and repaint the apps.
    function onWallpaperThemeChanged(): void {
        if (!ThemeSource.palette) throw new Error("invariant: ColorModeState.onWallpaperThemeChanged: ThemeSource has no palette")
        Tokens.setCustomTheme(ThemeSource.palette)
        if (previewId === "wallpaper") {
            Tokens.setTheme("wallpaper", true)
            dark = Tokens.isDarkTheme("wallpaper")
            return
        }
        if (chosen !== "wallpaper") return
        resolved = resolve(chosen)
        dark = Tokens.isDarkTheme(resolved)
        applyShell()
        debounce.restart()
    }

    // Move Tokens to the resolved theme (no fade at start-up).
    function applyShell(): void {
        if (!Tokens.palette) {
            console.warn("aptus: theme: tokens not loaded, the shell keeps its built-in colours")
            return
        }
        Tokens.setTheme(resolved, !firstRun)
    }

    // The command line of the repaint for a theme in effect: aptus-theme-apps --theme <id> --all --quiet.
    function appsCommand(theme: string): var {
        return [Tokens.rootDir + "/bin/aptus-theme-apps", "--theme", theme, "--all", "--quiet"]
    }

    // Run aptus-theme-apps for the resolved theme in the background (one run at a time, the last request wins).
    function repaintApps(): void {
        if (themeApps.running) {
            pending = true
            return
        }
        const command = appsCommand(resolved)
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
