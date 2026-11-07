pragma Singleton
// Apps: desktop entries, icons, running-app lookup.
// Owner: S3 (class → icon lookup for the bar), S4 (entries, launch, running apps). Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): until S3/S4 fills this service, each action method logs "not available yet"
    //   (category service.<name>) instead of throwing (phase-1 decision 6).

    // desktop entries
    property var entries: []
    // The icon name for a window class (desktop entry StartupWMClass, id, then the class itself).
    function iconFor(windowClass: string): string { throw new Error("Apps.iconFor: not implemented"); }
}
