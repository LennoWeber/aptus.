pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.components

// Editor for the apps kept in the dock: order, removal and a picker of the installed apps. Only declarations here.
Column {
    id: editor

    property var apps: []              // saved desktop entry ids, in dock order
    property bool picking              // the list of installed apps is open
    property string filter             // text typed in the picker
    property var catalog               // the desktop entries; names and icons are looked up through it so they follow its loading
    signal changed(var apps)           // the whole new list

    // TODO(phase 7): bind catalog to DesktopEntries.applications.values; installedApps/nameOf/iconOf read it, so names and icons show once the entries have loaded;
    // TODO(phase 7): drop the qs.models import if unused (lint info).
    // Installed, launchable apps as { id, name, icon }, sorted by name, without the ones already in the dock.
    function installedApps(): var {
        throw new Error("not implemented")
    }

    function nameOf(id: string): string {
        if (id === "") throw new Error("invariant: DockAppsEditor.nameOf: empty id")
        throw new Error("not implemented")
    }

    function iconOf(id: string): string {
        if (id === "") throw new Error("invariant: DockAppsEditor.iconOf: empty id")
        throw new Error("not implemented")
    }

    function shift(index: int, delta: int): void {
        if (Math.abs(delta) !== 1) throw new Error("invariant: DockAppsEditor.shift: delta must be -1 or 1")
        if (index < 0 || index >= apps.length) throw new Error("invariant: DockAppsEditor.shift: index outside the list")
        throw new Error("not implemented")
    }

    function removeAt(index: int): void {
        if (index < 0 || index >= apps.length) throw new Error("invariant: DockAppsEditor.removeAt: index outside the list")
        throw new Error("not implemented")
    }

    function addApp(id: string): void {
        if (id === "") throw new Error("invariant: DockAppsEditor.addApp: empty id")
        if (apps.indexOf(id) >= 0) throw new Error("invariant: DockAppsEditor.addApp: app already in the list")
        throw new Error("not implemented")
    }
}
