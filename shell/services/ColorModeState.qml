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
    property string applyError: ""
    property int debounceMs: 250               // several presses repaint the apps once

    Process {
        id: themeApps
    }

    Timer {
        id: debounce
        interval: root.debounceMs
    }
}
