pragma Singleton
// Apps: desktop entries, icons, running-app lookup.
// Owner: S3 (class → icon lookup for the bar), S4 (entries, launch, running apps). Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // desktop entries
    property var entries: []
    // The service works (S3: the class → icon and name lookup).
    // TODO(phase): true.
    readonly property bool available: false
    // Window class → { icon, name } looked up once (desktop entries change rarely; cleared when
    // they do).
    property var _byClass: ({})
    // The icon name for a window class (desktop entry StartupWMClass, id, then the class itself).
    // TODO(phase): entryFor(windowClass).icon, else the class; cached in _byClass, which
    //   DesktopEntries.applications changes clear.
    function iconFor(windowClass: string): string { Log.info("service.apps", "iconFor: not available yet"); return ""; }
    // The app's name for a window class (desktop entry name, else the class) — empty titles and tooltips.
    function nameFor(windowClass: string): string { throw new Error("not implemented"); }
    // The desktop entry for a window class or desktop-entry id (heuristicLookup), or null.
    function entryFor(windowClass: string): var { throw new Error("not implemented"); }
}
