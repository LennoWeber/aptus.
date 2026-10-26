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
        stdout: StdioCollector { id: generatorOutput }
        stderr: StdioCollector { id: generatorErrors }
        // qmllint disable signal-handler-parameters
        onExited: code => root.onGenerated(code)
        // qmllint enable signal-handler-parameters
    }

    FileView {
        id: paletteFile
        path: root.file
        blockLoading: true
        printErrors: false
    }

    // Make the palette for the picture at `path` (absolute) with the tone `tone` (auto | light | dark): runs
    // bin/aptus-wallpaper-theme, sets status to "working", then "ready" and `palette`, or "failed" and `error`. An empty path
    // or an unreadable picture fails; the previous palette stays.
    function generate(path: string, tone: string): void {
        if (["auto", "light", "dark"].indexOf(tone) < 0) throw new Error("invariant: ThemeSource.generate: tone is auto, light or dark")
        if (!path || path[0] !== "/") {
            status = "failed"
            error = "no wallpaper"
            return
        }
        if (generator.running) {
            queued = { path: path, tone: tone }
            return
        }
        status = "working"
        error = ""
        source = path
        generator.command = [helper, path, "--tone", tone, "--out", file]
        generator.running = true
    }

    // Make the palette for Wallpaper.current with the setting appearance.wallpaperTone; does nothing when it is already made for that picture and tone.
    function refresh(): void {
        if (!active) return
        generate(Wallpaper.current, tone)
    }

    // Read `file` into `palette` (start-up: the palette of the last run), when it belongs to Wallpaper.current.
    function read(): void {
        try {
            const text = paletteFile.text()
            if (!text) return
            palette = JSON.parse(text)
            source = palette.source ? palette.source.path : ""
            status = "ready"
        } catch (e) {
            console.warn("aptus: wallpaper theme: cannot read " + file + ": " + e)
        }
    }

    // The generator finished: on code 0 read the file and emit changed(), else status "failed" with the first line of its stderr.
    function onGenerated(code: int): void {
        if (!Number.isInteger(code)) throw new Error("invariant: ThemeSource.onGenerated: exit code must be an integer")
        if (code === 0) {
            try {
                palette = JSON.parse(generatorOutput.text)
                status = "ready"
                error = ""
                changed()
            } catch (e) {
                status = "failed"
                error = "unreadable result"
            }
        } else {
            status = "failed"
            error = generatorErrors.text.trim().split("\n")[0] || ("exit code " + code)
            console.warn("aptus: wallpaper theme: " + error)
        }
        if (queued) {
            const next = queued
            queued = null
            if (next.path !== source || next.tone !== tone || code !== 0) generate(next.path, next.tone)
        }
    }
}
