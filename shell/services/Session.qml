pragma Singleton
import QtQuick

// Signatures only. Bodies come in phase 7.
QtObject {
    function lockScreen(): void {
        // TODO(phase 7): LockState.lock(). There is deliberately no suspend or hibernate function in this file.
        throw new Error("not implemented")
    }

    function logout(): void {
        throw new Error("not implemented")
    }

    function restart(): void {
        throw new Error("not implemented")
    }

    function shutdown(): void {
        throw new Error("not implemented")
    }
}
