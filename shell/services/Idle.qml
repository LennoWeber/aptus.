pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Idle policy: lock first, then screen off. NEVER sleep. Replaces the user's hypridle only while aptus runs
// (the user's hypridle.conf stays as a safety net when another shell is active).
// Caffeine (manual) and, if wanted, a fullscreen window hold back both the lock and the screen-off.
Singleton {
    id: root

    property var lockState                // LockState, set by shell.qml
    property int lockAfterMin: 5          // 0 = never
    property int screenOffAfterMin: 10    // 0 = never; only in use together with a lock that comes earlier
    property string lidCloseAction: "lock"  // "lock" | "nothing"
    property bool keepAwakeWhenFullscreen: true

    property bool caffeine
    property bool fullscreenInhibit
    // The actual IdleInhibitor lives in the bar window (it needs a window): see Bar.qml.
    property bool inhibit: caffeine || fullscreenInhibit

    property bool lidClosed

    // Screen off only makes sense after a lock; both never without it.
    readonly property bool screenOffValid: screenOffAfterMin > 0 && lockAfterMin > 0 && screenOffAfterMin > lockAfterMin

    IdleMonitor {
        enabled: root.lockAfterMin > 0
        respectInhibitors: true
        timeout: root.lockAfterMin * 60
        onIsIdleChanged: if (isIdle && root.lockState) root.lockState.lock()
    }

    IdleMonitor {
        enabled: root.screenOffValid
        respectInhibitors: true
        timeout: root.screenOffAfterMin * 60
        // Any input brings the screen back; the lock is already in place by then.
        onIsIdleChanged: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms({ action = '" + (isIdle ? "off" : "on") + "' })"])
    }

    // A fullscreen window (reading, video) keeps the screen awake.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen") root.fullscreenInhibit = root.keepAwakeWhenFullscreen && event.data === "1"
        }
    }

    // Lid state, read from ACPI because Quickshell has no lid type. Only used to lock when the lid closes.
    Process {
        id: lidProbe
        command: ["sh", "-c", "cat /proc/acpi/button/lid/*/state 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const closed = text.indexOf("closed") >= 0
                if (closed && !root.lidClosed) root.onLidClosed()
                root.lidClosed = closed
            }
        }
    }
    Timer {
        interval: 2000
        repeat: true
        running: root.lidCloseAction === "lock"
        onTriggered: lidProbe.running = true
    }

    // Caffeine.
    function setCaffeine(on: bool): void {
        caffeine = on
    }

    function setFullscreenInhibit(on: bool): void {
        fullscreenInhibit = on
    }

    // Lock only: logind already ignores the lid (50-hp-sleep.conf, checked by the installer).
    function onLidClosed(): void {
        if (lockState) lockState.lock()
    }
}
