import QtQuick
import Quickshell

// 15 second confirmation after applying settings.
// Phase 2/3/4 skeleton. Body comes in phase 7.
PanelWindow {
    // TODO(phase 7): always above everything, large buttons, operable by mouse and touch even if shortcuts are broken.
    // TODO(phase 7): shows the countdown; Revert now is as big as Keep.

    property int secondsLeft
    property bool isOpen
    signal confirmed()
    signal reverted()

    function start(seconds: int): void {
        if (!Number.isInteger(seconds) || seconds < 1) throw new Error("invariant: ConfirmDialog.start: seconds must be an integer >= 1")
        throw new Error("not implemented")
    }

    function stop(): void {
        throw new Error("not implemented")
    }
}
