import QtQuick

// Content of the lockscreen on each screen.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): blurred wallpaper, large clock, password pill; notification text hidden unless allowed.
    // TODO(phase 7): rotates with the screen orientation.

    property var lockState  // LockState
    property string wallpaperPath
    property real blurRadius
    property bool showClock

    function focusPassword(): void {
        throw new Error("not implemented")
    }
}
