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
    onFitChanged: syncLogin()
    onLoginSyncChanged: syncLogin()
    onLoginSyncedChanged: if (loginSyncedLoaded) syncedView.setText(loginSynced)
    property bool loginSyncedLoaded            // the remembered key was read, so a change of it is written back
    property string loginKeyPending            // "path|fit" of the run in flight, "" for a manual call
    property bool loginQueued                  // a sync was asked for while one was running
    readonly property string syncedFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/aptus/login-wallpaper"

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
        loginKeyPending = path === "" ? "" : path + "|" + fitName(fit)
        // The manual call (loginStatus "working") may ask for the admin password; syncLogin() never does.
        loginRun.command = path === "" ? ["pkexec", loginHelper, "--clear"] : ["pkexec", loginHelper, path, "--fit", fitName(fit)]
        loginRun.running = true
    }

    function setWallpaper(path: string): void {
        if (path !== "" && path[0] !== "/") throw new Error("invariant: Wallpaper.setWallpaper: path must be absolute")
        current = path
        stateView.setText(path)
        ThemeSource.refresh()
        syncLogin()
    }

    FileView {
        id: stateView
        path: root.stateFile
        blockLoading: true
        printErrors: false
        Component.onCompleted: root.current = text().trim()
    }

    // The picture and fit that were last handed to the login helper.
    FileView {
        id: syncedView
        path: root.syncedFile
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            root.loginSynced = text().trim()
            root.loginSyncedLoaded = true
        }
    }

    Component.onCompleted: helperCheck.running = true

    Process {
        id: helperCheck
        command: ["test", "-x", root.loginHelper]
        // qmllint disable signal-handler-parameters
        onExited: code => { root.loginSupported = code === 0; root.syncLogin() }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: loginRun
        // 126 means the password prompt was dismissed: no error to show.
        // qmllint disable signal-handler-parameters
        onExited: code => root.onLoginExited(code)
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
        if (!(fit >= Enums.WallpaperFit.Fill && fit <= Enums.WallpaperFit.Tile)) throw new Error("invariant: Wallpaper.syncLogin: unknown fit")
        if (current !== "" && current[0] !== "/") throw new Error("invariant: Wallpaper.syncLogin: the picture path must be absolute")
        if (!loginSync || !loginSupported || !loginSyncedLoaded || current === "") return
        const key = current + "|" + fitName(fit)
        if (key === loginSynced) return
        if (loginRun.running) {
            loginQueued = true
            return
        }
        loginKeyPending = key
        // pkcheck without interaction succeeds only when the polkit rule lets the active session through without a password
        // (install.sh --greeter); otherwise exit 77 and nothing is shown.
        loginRun.command = ["sh", "-c", "pkcheck --action-id org.aptus.greeter-wallpaper --process $$ >/dev/null 2>&1 || exit 77; exec pkexec \"$1\" \"$2\" --fit \"$3\"",
            "sh", loginHelper, current, fitName(fit)]
        loginRun.running = true
    }

    // The login helper finished: a manual call reports in loginStatus, an automatic one remembers what it handed over.
    function onLoginExited(code: int): void {
        if (!Number.isInteger(code)) throw new Error("invariant: Wallpaper.onLoginExited: exit code must be an integer")
        if (loginStatus === "working") {
            // 126 means the password prompt was dismissed: no error to show.
            loginStatus = code === 0 ? "done" : code === 126 ? "" : "failed"
            if (code === 0) loginSynced = loginKeyPending
        } else if (code === 0) {
            loginSynced = loginKeyPending
        } else if (code === 77) {
            console.info("aptus: login screen picture not synced: the polkit rule asks for a password (run install.sh --greeter again)")
        } else {
            console.warn("aptus: login screen picture not synced (login helper exited with " + code + ")")
        }
        loginKeyPending = ""
        if (loginQueued) {
            loginQueued = false
            syncLogin()
        }
    }

    // The name of an Enums.WallpaperFit as the setting and the login config spell it.
    function fitName(fit: int): string {
        if (!(fit >= Enums.WallpaperFit.Fill && fit <= Enums.WallpaperFit.Tile)) throw new Error("invariant: Wallpaper.fitName: unknown fit")
        return ["fill", "fit", "stretch", "center", "tile"][fit]
    }
}
