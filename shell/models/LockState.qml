import QtQuick

// State of the lockscreen (Quickshell session lock + PAM).
QtObject {
    property bool locked
    property string userName
    property string password         // typed text, never stored or logged
    property bool authenticating
    property int failedAttempts
    property string message          // short feedback, e.g. "Wrong password"
    property bool capsLockOn
    property bool keyboardVisible    // built-in on-screen keyboard (tablet mode / touch)
    property bool showNotificationContent  // mirrors lock.showNotificationContent

    function lock(): void {
        // TODO(phase 7): Wayland session lock; the lock always comes before the screen switches off.
        throw new Error("not implemented")
    }

    function setPassword(text: string): void {
        if (typeof text !== "string") throw new Error("invariant: LockState.setPassword: password must be a string")
        throw new Error("not implemented")
    }

    function clearPassword(): void {
        throw new Error("not implemented")
    }

    // Authenticate through PAM.
    function tryUnlock(): void {
        if (!locked) throw new Error("invariant: LockState.tryUnlock: unlock while not locked")
        if (password === "") throw new Error("invariant: LockState.tryUnlock: empty password")
        if (authenticating) throw new Error("invariant: LockState.tryUnlock: an authentication is already running")
        // TODO(phase 7): PAM only; never store or log the password, clear it right after use.
        throw new Error("not implemented")
    }

    // Built-in on-screen keyboard.
    function setKeyboardVisible(on: bool): void {
        throw new Error("not implemented")
    }
}
