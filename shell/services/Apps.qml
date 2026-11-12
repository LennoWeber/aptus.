pragma Singleton
// Apps: desktop entries, icons, running-app lookup.
// Owner: S3 (class → icon lookup for the bar), S4 (entries, launch, running apps).
import QtQuick
import Quickshell

Singleton {
    id: root

    // desktop entries
    property var entries: []
    // The service works (S3: the class → icon and name lookup).
    readonly property bool available: true
    // Window class → { icon, name } looked up once (desktop entries change rarely; cleared when
    // they do).
    property var _byClass: ({})
    // The icon name for a window class (desktop entry StartupWMClass, id, then the class itself).
    function iconFor(windowClass: string): string { return _lookup(windowClass).icon; }
    // The app's name for a window class (desktop entry name, else the class) — empty titles and tooltips.
    function nameFor(windowClass: string): string { return _lookup(windowClass).name; }
    // The desktop entry for a window class or desktop-entry id (heuristicLookup), or null.
    function entryFor(windowClass: string): var {
        if (!windowClass) return null;
        return DesktopEntries.byId(windowClass) || DesktopEntries.heuristicLookup(windowClass) || null;
    }
    // The desktop entry id for a window class ("" none), from the cache (Hypr.windowForApp).
    function idFor(windowClass: string): string { return _lookup(windowClass).id; }
    // { icon, name, id } of a class, cached in _byClass.
    function _lookup(windowClass: string): var {
        const c = String(windowClass || "");
        if (c === "") return { icon: "", name: "", id: "" };
        const hit = _byClass[c];
        if (hit) return hit;
        const e = entryFor(c);
        const r = { icon: e && e.icon ? e.icon : c, name: e && e.name ? e.name : c, id: e ? e.id : "" };
        _byClass[c] = r;        // a cache: no binding reads it
        return r;
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged(): void { root._byClass = {}; }
    }
}
