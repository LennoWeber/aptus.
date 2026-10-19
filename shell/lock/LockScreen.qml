pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.models

// Wayland session lock with PAM sign-in. If the shell dies while locked, the compositor keeps the screen locked
// (nobody gets in); switch to a text console (Ctrl+Alt+F3), log in and start the shell again.
Scope {
    id: root

    property var lockState   // LockState
    property bool use24h: true

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    WlSessionLock {
        id: sessionLock
        locked: root.lockState ? root.lockState.locked : false

        WlSessionLockSurface {
            // The solid fallback colour shows for a moment before the first frame.
            color: "#F4F3EF"
            LockSurface {
                anchors.fill: parent
                lockState: root.lockState
                use24h: root.use24h
                now: clock.date
            }
        }
    }

    // Always the current user. The password goes straight to PAM and is dropped right after.
    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            if (responseRequired) respond(root.lockState.password)
        }
        // The result enum of PamContext is not known to qmllint.
        // qmllint disable signal-handler-parameters
        onCompleted: result => {
            root.lockState.authFinished(result === PamResult.Success, "Wrong password")
        }
        onError: {
            root.lockState.authFinished(false, "Sign-in is not available")
        }
        // qmllint enable signal-handler-parameters
    }

    Connections {
        target: root.lockState
        function onAuthRequested() {
            pam.abort()
            pam.start()
        }
    }
}
