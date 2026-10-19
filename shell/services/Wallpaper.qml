pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The wallpaper: the shell draws it itself (WallpaperLayer), so no wallpaper daemon is needed.
// The chosen file is remembered in ~/.local/state/aptus/wallpaper; the folder to pick from is a setting.
Singleton {
    id: root

    property string directory           // settings wallpaper.directory, empty = ~/Pictures/Wallpapers
    readonly property string folder: directory || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    property string current             // absolute path, empty = none
    property var list: []               // { path, name }
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/aptus/wallpaper"

    function scan(): void {
        lister.running = true
    }

    function setWallpaper(path: string): void {
        if (path !== "" && path[0] !== "/") throw new Error("invariant: Wallpaper.setWallpaper: path must be absolute")
        current = path
        stateView.setText(path)
    }

    FileView {
        id: stateView
        path: root.stateFile
        blockLoading: true
        printErrors: false
        Component.onCompleted: root.current = text().trim()
    }

    Process {
        id: lister
        command: ["sh", "-c", "find \"$1\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort", "sh", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                root.list = text.split("\n").filter(p => p !== "").map(p => ({ path: p, name: p.split("/").pop() }))
            }
        }
    }
}
