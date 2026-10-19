import QtQuick

// State of the greetd greeter (login screen).
QtObject {
    property var users               // list of { name, displayName, avatarPath }
    property string selectedUser
    property var sessions            // list of SessionInfo
    property string selectedSession
    property string password         // typed text, never stored or logged
    property bool authenticating
    property string message          // short feedback
    property bool capsLockOn
    property bool keyboardVisible    // built-in on-screen keyboard (tablet mode / touch)
    property string lastUser         // remembered between boots
    property string lastSession

    function loadUsers(): void {
        throw new Error("not implemented")
    }

    function selectUser(userName: string): void {
        if (!userName) throw new Error("invariant: GreeterState.selectUser: empty user name")
        throw new Error("not implemented")
    }

    function selectSession(sessionId: string): void {
        if (!sessionId) throw new Error("invariant: GreeterState.selectSession: empty session id")
        throw new Error("not implemented")
    }

    function setPassword(text: string): void {
        if (typeof text !== "string") throw new Error("invariant: GreeterState.setPassword: password must be a string")
        throw new Error("not implemented")
    }

    // Authenticate and start the session through greetd.
    function submit(): void {
        if (!selectedUser) throw new Error("invariant: GreeterState.submit: no user selected")
        if (!selectedSession) throw new Error("invariant: GreeterState.submit: no session selected")
        if (password === "") throw new Error("invariant: GreeterState.submit: empty password")
        if (authenticating) throw new Error("invariant: GreeterState.submit: an authentication is already running")
        // TODO(phase 7): authenticate through greetd and start the command of the selected SessionInfo.
        throw new Error("not implemented")
    }

    function cancel(): void {
        throw new Error("not implemented")
    }

    // Enums.PowerAction (restart or shutdown only).
    function powerAction(action: int): void {
        if (action !== Enums.PowerAction.Restart && action !== Enums.PowerAction.Shutdown) throw new Error("invariant: GreeterState.powerAction: the greeter offers only restart and shutdown")
        // TODO(phase 7): only restart and shutdown, no sleep entry.
        throw new Error("not implemented")
    }
}
