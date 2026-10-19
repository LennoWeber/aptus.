import QtQuick
import Quickshell
import qs.models
import qs.theme

// Entry point of the aptus greeter. greetd starts it inside cage (a one-window compositor), so it is an ordinary
// full-size window. Settings come from /etc/aptus/greeter.json; APTUS_GREETER_CONFIG and APTUS_GREETER_CACHE
// override the paths for tests.
ShellRoot {
    GreeterState {
        id: greeterState
        configPath: Quickshell.env("APTUS_GREETER_CONFIG") || "/etc/aptus/greeter.json"
        cachePath: Quickshell.env("APTUS_GREETER_CACHE") || "/var/cache/aptus-greeter/state.json"
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    FloatingWindow {
        visible: true
        title: "aptus greeter"
        color: Tokens.bg
        implicitWidth: 1280
        implicitHeight: 720

        GreeterSurface {
            anchors.fill: parent
            greeterState: greeterState
            now: clock.date
        }
    }
}
