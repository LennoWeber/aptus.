import QtQuick
import Quickshell
import Quickshell.Io

// User settings, loaded from config/settings.json and editable in the Settings mode.
Scope {
    id: root
    // The whole settings tree, loaded from config/settings.json plus the user's overrides. The typed properties
    // below are views of single paths in this tree; get/set work on paths such as 'ai.dockEdge'.
    property var values: ({})
    property var defaults: ({})
    readonly property string rootDir: Quickshell.env("APTUS_ROOT") || Quickshell.shellPath("..")
    property string userConfigPath: Quickshell.env("HOME") + "/.config/aptus/settings.json"
    signal valueChanged(string path)

    FileView {
        id: defaultsFile
        path: root.rootDir + "/config/settings.json"
        blockLoading: true
    }

    FileView {
        id: userFile
        path: root.userConfigPath
        blockLoading: true
        printErrors: false   // the user file does not exist until the first change
    }

    Component.onCompleted: load()

    property int defaultLauncherMode   // Enums.LauncherMode, always starts as Apps by default
    property var modeKeys              // map LauncherMode -> key sequence, e.g. "Ctrl+1"
    property string browserCommand
    property string browserWindowClass
    property string searchEngineId
    property var searchEngines         // list of { id, name, urlTemplate }
    property string aiDefaultProviderId
    property int aiDockEdge            // Enums.DockEdge
    property int aiDockWidthPx
    property bool lockShowNotificationContent
    property int lockAfterMin          // system.lockAfterMin, 5
    property int screenOffAfterMin     // system.screenOffAfterMin, 10, always after the lock
    property string terminalCommand    // system.terminal
    property string fileManagerCommand // system.fileManager
    property string lidCloseAction     // "lock" | "nothing", never suspend
    property bool touchAutoKeyboard    // system on-screen keyboard for text fields (only if one is installed)
    property string lockKeyboardMode   // built-in keyboard on lockscreen/greeter: "auto" | "always" | "never"
    property bool keepAwakeWhenFullscreen  // fullscreen windows (reading, video) block auto-lock and screen off
    property int minTouchTargetPx
    property bool edgeGesturesEnabled
    property var edgeGestureActions    // map edge ("top", "left", ...) -> action id
    property int edgeStripWidthPx
    property bool tabletBarAutoHide
    property bool autoRotate
    property int settingsConfirmTimeoutSec  // 15
    property string weatherLocationName
    property real weatherLatitude
    property real weatherLongitude
    property string weatherSource      // "open-meteo"
    property string calendarSourceKind // "ics" | "google"
    property string calendarIcsUrl
    property bool escapeStepsBack      // Esc: detail -> control center -> closed

    // Read defaults and the user's overrides.
    function load(): void {
        const read = (view) => {
            try {
                const text = view.text()
                return text ? JSON.parse(text) : ({})
            } catch (e) {
                console.warn("aptus: cannot read " + view.path + ": " + e)
                return ({})
            }
        }
        // Merge the user's values over the defaults; keys that are not in the defaults are ignored.
        const merge = (base, over) => {
            if (over === null || typeof over !== "object" || Array.isArray(over)) return over
            const out = Object.assign({}, base)
            for (const key in over) {
                if (!(key in base)) continue
                out[key] = (typeof base[key] === "object" && base[key] !== null && !Array.isArray(base[key])) ? merge(base[key], over[key]) : over[key]
            }
            return out
        }
        defaults = read(defaultsFile)
        values = merge(defaults, read(userFile))
        refreshViews()
    }


    // Copy the typed properties from the settings tree. Called after load() and every set().
    function refreshViews(): void {
        const mode = { apps: Enums.LauncherMode.Apps, web: Enums.LauncherMode.Web, settings: Enums.LauncherMode.Settings, ai: Enums.LauncherMode.Ai, clipboard: Enums.LauncherMode.Clipboard }
        const edge = { right: Enums.DockEdge.Right, left: Enums.DockEdge.Left, bottom: Enums.DockEdge.Bottom }
        defaultLauncherMode = mode[get("launcher.defaultMode")] ?? Enums.LauncherMode.Apps
        const keys = get("launcher.modeKeys") || ({})
        const byMode = {}
        for (const name in keys) if (name in mode) byMode[mode[name]] = keys[name]
        modeKeys = byMode
        browserCommand = get("browser.command")
        browserWindowClass = get("browser.windowClass")
        searchEngineId = get("browser.searchEngine")
        searchEngines = get("browser.searchEngines")
        aiDefaultProviderId = get("ai.defaultProvider")
        aiDockEdge = edge[get("ai.dockEdge")] ?? Enums.DockEdge.Right
        aiDockWidthPx = get("ai.dockWidth")
        lockShowNotificationContent = get("lock.showNotificationContent")
        lockAfterMin = get("system.lockAfterMin")
        screenOffAfterMin = get("system.screenOffAfterMin")
        terminalCommand = get("system.terminal")
        fileManagerCommand = get("system.fileManager")
        lidCloseAction = get("system.lidClose")
        touchAutoKeyboard = get("touch.autoOnScreenKeyboard")
        lockKeyboardMode = get("touch.lockKeyboard")
        keepAwakeWhenFullscreen = get("system.keepAwakeWhenFullscreen")
        minTouchTargetPx = get("touch.minTargetPx")
        edgeGesturesEnabled = get("touch.edgeGestures.enabled")
        edgeGestureActions = get("touch.edgeGestures.actions")
        edgeStripWidthPx = get("touch.edgeGestures.stripWidthPx")
        tabletBarAutoHide = get("touch.tabletBarAutoHide")
        autoRotate = get("touch.autoRotate")
        settingsConfirmTimeoutSec = get("settingsApp.confirmTimeoutSec")
        weatherLocationName = get("weather.locationName")
        weatherLatitude = get("weather.latitude")
        weatherLongitude = get("weather.longitude")
        weatherSource = get("weather.source")
        calendarSourceKind = get("calendar.sourceKind")
        calendarIcsUrl = get("calendar.icsUrl")
        escapeStepsBack = get("navigation.escapeStepsBack")
        // Bar settings are read directly with get("bar.…") by the bar.
    }

    // Value at a settings.json path, e.g. 'bar.clockFormat'.
    function get(path: string): var {
        if (!path) throw new Error("invariant: AppSettings.get: empty path")
        if (!values) throw new Error("invariant: AppSettings.get: settings not loaded")
        return path.split(".").reduce((node, key) => (node === undefined || node === null ? undefined : node[key]), values)
    }

    function set(path: string, value: var): void {
        if (!path) throw new Error("invariant: AppSettings.set: empty path")
        if (!values) throw new Error("invariant: AppSettings.set: settings not loaded")
        const keys = path.split(".")
        const next = Object.assign({}, values)
        let node = next
        for (let i = 0; i < keys.length - 1; i++) {
            node[keys[i]] = Object.assign({}, node[keys[i]])
            node = node[keys[i]]
        }
        node[keys[keys.length - 1]] = value
        values = next        // a new root object, so every view re-evaluates
        refreshViews()
        valueChanged(path)
    }

    function resetToDefault(path: string): void {
        if (!path) throw new Error("invariant: AppSettings.resetToDefault: empty path")
        if (!defaults) throw new Error("invariant: AppSettings.resetToDefault: settings not loaded")
        const fallback = path.split(".").reduce((node, key) => (node === undefined || node === null ? undefined : node[key]), defaults)
        set(path, fallback)
    }

    // Write overrides to ~/.config/aptus/.
    function writeUserConfig(): void {
        if (!values) throw new Error("invariant: AppSettings.writeUserConfig: settings not loaded")
        if (!userConfigPath) throw new Error("invariant: AppSettings.writeUserConfig: no user config path")
        // TODO(phase 7): write only values that differ from the defaults.
        throw new Error("not implemented")
    }
}
