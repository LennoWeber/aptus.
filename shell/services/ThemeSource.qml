pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.models

// The colours of the wallpaper as a theme (setting appearance.theme = "wallpaper"). bin/aptus-wallpaper-theme reads the
// picture and writes a complete palette in the format of theme/tokens.json (palette.themes) to `file`; aptus-theme-apps
// reads the same file. `palette` is that file's content once it belongs to `source`.
Singleton {
    id: root

    property string source                 // the picture the palette was made from, empty = none yet
    property string tone: "auto"           // appearance.wallpaperTone: auto | light | dark
    property var palette: null             // the generated palette ({ name, base, bg, ..., accent }) or null
    property string status: "idle"         // "idle" | "working" | "ready" | "failed"
    property string error                  // short reason while status is "failed"
    readonly property string file: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/aptus/wallpaper-theme.json"
    readonly property string helper: (Quickshell.env("APTUS_ROOT") || Quickshell.shellPath("..")) + "/bin/aptus-wallpaper-theme"

    signal changed()                       // `palette` has a new value

    Process {
        id: generator
        stderr: StdioCollector { id: generatorErrors }
    }

    FileView {
        id: paletteFile
        path: root.file
        printErrors: false
    }
}
