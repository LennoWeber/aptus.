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
    property bool active                   // the wallpaper theme is chosen or previewed: refresh() makes it
    property var queued: null              // { path, tone } asked for while a run was going
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

    // Make the palette for the picture at `path` (absolute) with the tone `tone` (auto | light | dark): runs
    // bin/aptus-wallpaper-theme, sets status to "working", then "ready" and `palette`, or "failed" and `error`. An empty path
    // or an unreadable picture fails; the previous palette stays.
    function generate(path: string, tone: string): void {
        if (["auto", "light", "dark"].indexOf(tone) < 0) throw new Error("invariant: ThemeSource.generate: tone is auto, light or dark")
        throw new Error("not implemented")
    }

    // Make the palette for Wallpaper.current with the setting appearance.wallpaperTone; does nothing when it is already made for that picture and tone.
    function refresh(): void {
        throw new Error("not implemented")
    }

    // Read `file` into `palette` (start-up: the palette of the last run), when it belongs to Wallpaper.current.
    function read(): void {
        throw new Error("not implemented")
    }

    // The generator finished: on code 0 read the file and emit changed(), else status "failed" with the first line of its stderr.
    function onGenerated(code: int): void {
        if (!Number.isInteger(code)) throw new Error("invariant: ThemeSource.onGenerated: exit code must be an integer")
        throw new Error("not implemented")
    }
}
