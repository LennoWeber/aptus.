pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.models

// The wallpaper: the shell draws it itself (WallpaperLayer), so no wallpaper daemon is needed.
// The chosen file is remembered in ~/.local/state/aptus/wallpaper; the folder to pick from is a setting.
Singleton {
    id: root

    // colours read from `current`, the source of the picture-based theme
    readonly property WallpaperColors colors: WallpaperColors {}

    property string directory           // settings wallpaper.directory, empty = ~/Pictures/Wallpapers
    readonly property string folder: directory || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    property string current             // absolute path, empty = none
    property var list: []               // { path, name }
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/aptus/wallpaper"

    function scan(): void {
        lister.running = true
        helperCheck.running = true
    }

    // The login screen picture is set by a root helper installed with `install.sh --greeter`; without it there is no such action.
    readonly property string loginHelper: "/usr/local/bin/aptus-greeter-wallpaper"
    property bool loginSupported
    property string loginStatus         // "", "working", "done", "failed"

    // An empty path removes the login picture.
    function setLoginWallpaper(path: string): void {
        if (!loginSupported) throw new Error("invariant: Wallpaper.setLoginWallpaper: the login helper is not installed")
        if (path !== "" && path[0] !== "/") throw new Error("invariant: Wallpaper.setLoginWallpaper: path must be absolute")
        loginStatus = "working"
        loginRun.command = ["pkexec", loginHelper, path === "" ? "--clear" : path]
        loginRun.running = true
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
        id: helperCheck
        command: ["test", "-x", root.loginHelper]
        // qmllint disable signal-handler-parameters
        onExited: code => root.loginSupported = code === 0
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: loginRun
        // 126 means the password prompt was dismissed: no error to show.
        // qmllint disable signal-handler-parameters
        onExited: code => root.loginStatus = code === 0 ? "done" : code === 126 ? "" : "failed"
        // qmllint enable signal-handler-parameters
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
