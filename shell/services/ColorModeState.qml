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

    property var appSettings    // AppSettings: reads and writes appearance.colorMode
    property var nightLight     // NightLightState: decides `auto`

    property string chosen: "light"            // appearance.theme as set: light | dark | auto | ocean | forest | dusk | sand | sky | wallpaper
    property string resolved: "light"          // the theme in effect: `chosen`, or light/dark for auto, or the previous one while the wallpaper theme is not ready
    property string previewId: ""              // the theme the picker shows right now, "" when none (the shell shows it, the apps do not)
    property bool dark: false                  // the base of the theme showing is dark
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
            // TODO(phase 7, themes): react to appearance.theme (and appearance.wallpaperTone, wallpaper.fit is not its business); the path "appearance.colorMode" is gone.
            if (path === "" || path === "appearance.colorMode") root.onSettingChanged(path)
        }
    }

    Connections {
        // TODO(phase 7, themes): add a Connections to ThemeSource (onChanged -> onWallpaperThemeChanged) and to Tokens? (no: Tokens does not signal).
        target: root.nightLight
        function onEnabledChanged(): void { root.onNightLightChanged() }
    }

    // The theme in effect for the setting value `chosen`: itself, light or dark for auto (dark while nightLight.enabled), and for
    // wallpaper the id "wallpaper" once ThemeSource.palette is there, else the theme that was showing.
    function resolve(chosen: string): string {
        // TODO(phase 7, themes): body is the old light/dark resolver: return the id (auto -> light or dark by nightLight.enabled, wallpaper -> "wallpaper" only when ThemeSource.palette is set, else `resolved`); isValid(chosen) first.
        if (!(m >= Enums.ColorMode.Light && m <= Enums.ColorMode.Auto)) throw new Error("invariant: ColorModeState.resolve: unknown mode")
        if (!nightLight) throw new Error("invariant: ColorModeState.resolve: nightLight not set")
        return m === Enums.ColorMode.Dark || (m === Enums.ColorMode.Auto && nightLight.enabled === true)
    }

    // Start-up: read the setting, set the shell to it without a fade, repaint the apps only if the state differs.
    function start(): void {
        if (!appSettings || !nightLight) throw new Error("invariant: ColorModeState.start: appSettings and nightLight must be set")
        // TODO(phase 7, themes): start(): chosen = appSettings.theme; resolved = resolve(chosen); Tokens.setTheme(resolved, false); ThemeSource.read()/refresh() before resolving wallpaper; apps repaint as before. `mode` and `dark` (= Tokens.isDarkTheme(resolved)).
        mode = appSettings.colorMode
        dark = resolve(mode)
        Tokens.colorModeFade = false
        applyShell()
        Tokens.colorModeFade = true
        repaintApps()
    }

    // Take the setting and the night light into account: when what is in effect changes, move the shell and repaint the apps.
    // TODO(phase 7, themes): update(): compare `resolved`, not a bool; chosen from appSettings.theme; previewId ends when the setting changes.
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

    // Choose a theme (a value of appearance.theme): write the setting; valueChanged then switches the shell and repaints the apps.
    function setTheme(id: string): void {
        if (!(m >= Enums.ColorMode.Light && m <= Enums.ColorMode.Auto)) throw new Error("invariant: ColorModeState.setMode: unknown mode")
        if (!appSettings) throw new Error("invariant: ColorModeState.setMode: appSettings not set")
        // TODO(phase 7, themes): write appearance.theme with the id (isValid first); the migration of the old appearance.colorMode is in AppSettings.migrateValues.
        appSettings.set("appearance.colorMode", nameFromMode(m))
        appSettings.writeUserConfig()     // so the choice survives a restart
    }

    // Light <-> dark by hand; Auto becomes the opposite of what is in effect. (Replaced by next() and the picker; goes in phase 7.)
    // TODO(phase 7, themes): remove; Super+T opens the picker (IpcHandlers.themeModeToggle) and next(step) cycles.
    function toggle(): void {
        setMode(dark ? Enums.ColorMode.Light : Enums.ColorMode.Dark)
    }

    // Move Tokens to the resolved mode.
    function applyShell(): void {
        if (!Tokens.palette) {
            console.warn("aptus: colour mode: tokens not loaded, the shell keeps its built-in colours")
            return
        }
        // TODO(phase 7, themes): Tokens.setTheme(resolved, true) with the preview taking precedence; Tokens.darkAmount is gone.
        Tokens.darkAmount = dark ? 1 : 0
    }

    // The command line of the repaint for a theme in effect: aptus-theme-apps --theme <id> --all --quiet.
    function appsCommand(theme: string): var {
        // TODO(phase 7, themes): ["--theme", theme, "--all", "--quiet"]; --if-changed compares the theme id (and the wallpaper palette file).
        return [Tokens.rootDir + "/bin/aptus-theme-apps", "--mode", isDark ? "dark" : "light", "--all", "--quiet"]
    }

    // Run aptus-theme-apps for the resolved mode in the background (one run at a time, the last request wins).
    function repaintApps(): void {
        if (themeApps.running) {
            pending = true
            return
        }
        // TODO(phase 7, themes): appsCommand(resolved), not the old boolean.
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

    // Whether `id` is a value of appearance.theme: light, dark, auto, wallpaper or one of the themes of tokens.json.
    function isValid(id: string): bool {
        throw new Error("not implemented")
    }

    // The values the picker steps through, in its order: Tokens.themeIds() (light, dark, the colour themes, wallpaper).
    function choices(): var {
        throw new Error("not implemented")
    }

    // Choose the theme `step` places after (or before, negative) the one in effect; wraps around. Used by Super+T in the picker.
    function next(step: int): void {
        throw new Error("not implemented")
    }

    // Show the theme `id` in the shell only (the picker's preview); the apps and the setting stay as they are.
    function preview(id: string): void {
        throw new Error("not implemented")
    }

    // End the preview: back to the theme in effect (resolved).
    function cancelPreview(): void {
        throw new Error("not implemented")
    }

    // Keep the previewed theme: same as setTheme(previewId), then the preview ends.
    function commitPreview(): void {
        throw new Error("not implemented")
    }

    // ThemeSource has a new palette (the wallpaper changed): when the wallpaper theme is chosen, fade to it and repaint the apps.
    function onWallpaperThemeChanged(): void {
        throw new Error("not implemented")
    }

    // The setting appearance.theme, or light (with a warning) when it is not a theme, e.g. a hand-edited file.
    function settingTheme(): string {
        throw new Error("not implemented")
    }

    // Tell ThemeSource whether the wallpaper theme is wanted (chosen or previewed) and which tone it should have.
    function followWallpaperTheme(): void {
        throw new Error("not implemented")
    }
}
