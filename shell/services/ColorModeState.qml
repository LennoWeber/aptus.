import QtQuick
import Quickshell
import Quickshell.Io
import qs.models
import qs.theme

// Light or dark for the shell and the apps (setting appearance.colorMode: light | dark | auto). Structure only.
// `mode` is the chosen value, `dark` what is in effect (auto is dark while the night light runs). `amount` is
// Tokens.darkAmount's target. After a change the apps are repainted by `aptus-theme-apps --mode <light|dark> --all`.
Scope {
    id: root

    property var appSettings    // AppSettings: reads and writes appearance.colorMode
    property var nightLight     // NightLightState: decides `auto`

    property int mode: Enums.ColorMode.Light
    property bool dark: false
    property real amount: 0                    // 0 light .. 1 dark
    property string applyStatus: "idle"        // idle | running | failed
    property string applyError: ""
    property int debounceMs: 250               // several Mod+T presses repaint the apps once
    property string themeAppsCommand: "aptus-theme-apps"

    // Repaints the apps in the background; the shell itself changes first.
    Process {
        id: themeApps
    }

    Timer {
        id: debounce
        interval: root.debounceMs
    }
}
