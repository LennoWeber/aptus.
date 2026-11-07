pragma Singleton
// Apps: desktop entries, icons, running-app lookup.
// Owner: S3 (class → icon lookup for the bar), S4 (entries, launch, running apps). Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // desktop entries
    property var entries: []
    // The icon name for a window class (desktop entry StartupWMClass, id, then the class itself).
    function iconFor(windowClass: string): string { throw new Error("Apps.iconFor: not implemented"); }
}
