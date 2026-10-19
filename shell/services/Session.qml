pragma Singleton
import QtQuick
import Quickshell

// Power actions of the session. There is deliberately no suspend or hibernate here (the HP Envy x360 has trouble
// with both under Linux). Locking is LockState.lock(), called from the IPC handler and the idle policy.
QtObject {
    function logout(): void {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"])
    }

    function restart(): void {
        Quickshell.execDetached(["systemctl", "reboot"])
    }

    function shutdown(): void {
        Quickshell.execDetached(["systemctl", "poweroff"])
    }
}
