import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// State of the greetd greeter (login screen). Reads the system config and /etc/passwd, talks to greetd, and
// remembers the last user and session in a cache file that the greeter's own user can write.
QtObject {
    id: root

    property string configPath: "/etc/aptus/greeter.json"
    property string cachePath: "/var/cache/aptus-greeter/state.json"

    property var users: []              // { name, displayName }
    property string selectedUser
    property var sessions: []           // { id, name, command }
    property string selectedSession
    property string wallpaper
    property bool showClock: true
    property bool showPowerButtons: true
    property bool rememberLastUser: true
    property bool rememberLastSession: true
    property bool authenticating
    property string message             // short feedback, empty when fine
    property bool keyboardVisible       // built-in on-screen keyboard
    property string keyboardMode: "auto"  // "auto" | "always" | "never"

    readonly property var selectedSessionInfo: sessions.find(s => s.id === selectedSession) || null

    // The typed password lives only between submit() and greetd's question; it is never stored or logged.
    property string pending

    function loadUsers(text: string): void {
        const found = []
        for (const line of text.split("\n")) {
            const f = line.split(":")
            if (f.length < 7) continue
            const uid = parseInt(f[2])
            if (uid < 1000 || uid >= 60000 || /nologin|false$/.test(f[6])) continue
            found.push({ name: f[0], displayName: f[4].split(",")[0] || f[0] })
        }
        users = found
    }

    function applyConfig(cfg: var): void {
        wallpaper = cfg.wallpaper || ""
        showClock = cfg.showClock !== false
        showPowerButtons = cfg.showPowerButtons !== false
        rememberLastUser = cfg.rememberLastUser !== false
        rememberLastSession = cfg.rememberLastSession !== false
        sessions = cfg.sessions || []
        selectedSession = cfg.defaultSession || (sessions.length > 0 ? sessions[0].id : "")
    }

    function applyCache(cache: var): void {
        if (rememberLastUser && cache.user && users.some(u => u.name === cache.user)) selectedUser = cache.user
        if (rememberLastSession && cache.session && sessions.some(s => s.id === cache.session)) selectedSession = cache.session
    }

    function selectUser(userName: string): void {
        if (!userName) throw new Error("invariant: GreeterState.selectUser: empty user name")
        if (authenticating) return
        selectedUser = userName
        message = ""
    }

    function selectSession(sessionId: string): void {
        if (!sessionId) throw new Error("invariant: GreeterState.selectSession: empty session id")
        selectedSession = sessionId
    }

    function setKeyboardVisible(on: bool): void {
        keyboardVisible = on && keyboardMode !== "never"
    }

    // Authenticate through greetd; on success the selected session starts.
    function submit(text: string): void {
        if (!selectedUser || !selectedSessionInfo || text === "" || authenticating) return
        if (!Greetd.available) {
            message = "Sign-in is not available"
            return
        }
        pending = text
        message = ""
        authenticating = true
        Greetd.createSession(selectedUser)
    }

    function cancel(): void {
        pending = ""
        authenticating = false
        Greetd.cancelSession()
    }

    // Enums.PowerAction (restart or shutdown only; there is no sleep entry).
    function powerAction(action: int): void {
        if (action === Enums.PowerAction.Restart) Quickshell.execDetached(["systemctl", "reboot"])
        else if (action === Enums.PowerAction.Shutdown) Quickshell.execDetached(["systemctl", "poweroff"])
        else throw new Error("invariant: GreeterState.powerAction: the greeter offers only restart and shutdown")
    }

    property FileView configFile: FileView {
        path: root.configPath
        blockLoading: true
    }
    property FileView passwdFile: FileView {
        path: "/etc/passwd"
        blockLoading: true
    }
    property FileView cacheFile: FileView {
        path: root.cachePath
        blockLoading: true
    }

    function load(): void {
        try { applyConfig(JSON.parse(configFile.text())) } catch (e) { console.error("aptus-greeter: cannot read " + configPath + ": " + e) }
        loadUsers(passwdFile.text())
        selectedUser = users.length > 0 ? users[0].name : ""
        try { applyCache(JSON.parse(cacheFile.text())) } catch (e) { /* first boot: nothing remembered */ }
    }

    Component.onCompleted: load()

    property Connections greetd: Connections {
        target: Greetd

        function onAuthMessage(text, isError, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.pending)
                root.pending = ""
            }
        }

        function onAuthFailure(text) {
            root.pending = ""
            root.authenticating = false
            root.message = "Wrong password"
            Greetd.cancelSession()
        }

        function onReadyToLaunch() {
            const info = root.selectedSessionInfo
            root.cacheFile.setText(JSON.stringify({ user: root.selectedUser, session: root.selectedSession }))
            Greetd.launch(info.command.split(" "), ["XDG_SESSION_TYPE=wayland"], true)
        }

        function onError(text) {
            root.pending = ""
            root.authenticating = false
            root.message = "Sign-in is not available"
        }
    }
}
