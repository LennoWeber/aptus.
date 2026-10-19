import QtQuick

// State of the lockscreen. The Wayland session lock and PAM live in LockScreen; this holds what the surfaces show.
QtObject {
    id: state

    property bool locked
    property string password         // typed text, only while a check runs, never stored or logged
    property bool authenticating
    property int failedAttempts
    property string message          // short feedback, e.g. "Wrong password"
    property bool keyboardVisible    // built-in on-screen keyboard (tablet mode / touch)
    property string keyboardMode: "auto"  // touch.lockKeyboard: "auto" | "always" | "never"
    property bool showNotificationContent  // mirrors lock.showNotificationContent

    // PAM is asked to check `password`.
    signal authRequested()

    // The lock always comes first; the screen only switches off afterwards.
    function lock(): void {
        if (locked) return
        password = ""
        message = ""
        failedAttempts = 0
        authenticating = false
        keyboardVisible = keyboardMode === "always"
        locked = true
    }

    function setPassword(text: string): void {
        if (typeof text !== "string") throw new Error("invariant: LockState.setPassword: password must be a string")
        password = text
    }

    function clearPassword(): void {
        password = ""
    }

    // Authenticate through PAM (see LockScreen); the password is cleared right after use.
    function tryUnlock(): void {
        if (!locked) throw new Error("invariant: LockState.tryUnlock: unlock while not locked")
        if (password === "") throw new Error("invariant: LockState.tryUnlock: empty password")
        if (authenticating) throw new Error("invariant: LockState.tryUnlock: an authentication is already running")
        authenticating = true
        message = ""
        authRequested()
    }

    // Called by LockScreen with the PAM result.
    function authFinished(success: bool, text: string): void {
        authenticating = false
        password = ""
        if (success) {
            locked = false
            message = ""
            return
        }
        failedAttempts += 1
        message = text
    }

    // Built-in on-screen keyboard; "never" keeps it away.
    function setKeyboardVisible(on: bool): void {
        keyboardVisible = on && keyboardMode !== "never"
    }
}
