pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.models

// The wallpaper: the shell draws it itself (WallpaperLayer), so no wallpaper daemon is needed.
// The chosen file is remembered in ~/.local/state/aptus/wallpaper; the folder to pick from is a setting.
Singleton {
    id: root

    // How the picture is placed (setting wallpaper.fit, Enums.WallpaperFit); the lock screen and the login screen use it too.
    property int fit: Enums.WallpaperFit.Fill
    // The login screen picture follows `current` (setting appearance.loginWallpaper); `loginSynced` is the picture that was
    // last handed to the login helper together with the fit, "" when none or after a failure.
    property bool loginSync: true
    property string loginSynced

    property string directory           // settings wallpaper.directory, empty = ~/Pictures/Wallpapers
    readonly property string folder: directory || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    property string current             // absolute path, empty = none
    property var list: []               // { path, name }
    property int count                  // list.length
    property bool loaded                // the folder was listed at least once
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/aptus/wallpaper"

    function scan(): void {
        lister.running = true
        helperCheck.running = true
    }

    // The login screen picture is set by a root helper installed with `install.sh --greeter`; without it there is no such action.
    readonly property string loginHelper: "/usr/local/bin/aptus-greeter-wallpaper"
    property bool loginSupported
    property string loginStatus         // "", "working", "done", "failed"

    // An empty path removes the login picture. `fit` is an Enums.WallpaperFit and goes into the login screen's config.
    function setLoginWallpaper(path: string, fit: int): void {
        if (!loginSupported) throw new Error("invariant: Wallpaper.setLoginWallpaper: the login helper is not installed")
        if (path !== "" && path[0] !== "/") throw new Error("invariant: Wallpaper.setLoginWallpaper: path must be absolute")
        loginStatus = "working"
        // TODO(phase 7, themes): append "--fit" and fitName(fit) when path is not empty. The manual call from the picker may ask for a password; syncLogin() must not.
        loginRun.command = ["pkexec", loginHelper, path === "" ? "--clear" : path]
        loginRun.running = true
    }

    function setWallpaper(path: string): void {
        if (path !== "" && path[0] !== "/") throw new Error("invariant: Wallpaper.setWallpaper: path must be absolute")
        // TODO(phase 7, themes): after storing: ThemeSource.refresh() (only matters when the theme is wallpaper) and syncLogin().
        current = path
        stateView.setText(path)
    }

    FileView {
        id: stateView
        path: root.stateFile
        blockLoading: true
        printErrors: false
        // TODO(phase 7, themes): ThemeSource.read() for the remembered picture after the state file is read.
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
        // TODO(phase 7, themes): on exit of an automatic sync set loginSynced (code 0) or log the failure; the manual call keeps loginStatus.
        onExited: code => root.loginStatus = code === 0 ? "done" : code === 126 ? "" : "failed"
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: lister
        command: ["sh", "-c", "find -L \"$1\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort", "sh", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                root.list = text.split("\n").filter(p => p !== "").map(p => ({ path: p, name: p.split("/").pop() }))
                root.count = root.list.length
                root.loaded = true
            }
        }
    }

    // Hand the current picture and fit to the login helper when loginSync is on, the helper is installed and they differ from
    // loginSynced. Quiet when the helper refuses (no password prompt is shown for an automatic sync); the reason goes to the log.
    function syncLogin(): void {
        throw new Error("not implemented")
    }

    // The name of an Enums.WallpaperFit as the setting and the login config spell it.
    function fitName(fit: int): string {
        throw new Error("not implemented")
    }
}
