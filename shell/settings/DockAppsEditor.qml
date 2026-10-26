pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.theme
import qs.components

// Editor for the apps kept in the dock: order, removal and a picker of the installed apps.
Column {
    id: editor

    property var apps: []              // saved desktop entry ids, in dock order
    property bool picking              // the list of installed apps is open
    property string filter             // text typed in the picker
    // The desktop entries, read by the lookups below so that names and icons update when the list has loaded.
    readonly property var catalog: DesktopEntries.applications.values
    signal changed(var apps)           // the whole new list

    spacing: 6

    function entryOf(id: string): var {
        if (editor.catalog.length < 0) return null
        return DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
    }

    // Installed, launchable apps as { id, name, icon }, sorted by name, without the ones already in the dock.
    function installedApps(): var {
        const q = editor.filter.trim().toLowerCase()
        const taken = new Set(editor.apps.map(a => (editor.entryOf(a) || { id: a }).id))
        const out = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay || taken.has(e.id)) continue
            if (q !== "" && e.name.toLowerCase().indexOf(q) < 0) continue
            out.push({ id: e.id, name: e.name, icon: e.icon })
        }
        out.sort((a, b) => a.name.localeCompare(b.name))
        return out
    }

    function nameOf(id: string): string {
        const e = editor.entryOf(id)
        return e ? e.name : id
    }

    function iconOf(id: string): string {
        const e = editor.entryOf(id)
        return e && e.icon ? Quickshell.iconPath(e.icon, true) : ""
    }

    function shift(index: int, delta: int): void {
        if (Math.abs(delta) !== 1) throw new Error("invariant: DockAppsEditor.shift: delta must be -1 or 1")
        if (index < 0 || index >= editor.apps.length) throw new Error("invariant: DockAppsEditor.shift: index outside the list")
        const target = index + delta
        if (target < 0 || target >= editor.apps.length) return
        const next = editor.apps.slice()
        const moved = next.splice(index, 1)[0]
        next.splice(target, 0, moved)
        editor.changed(next)
    }

    function removeAt(index: int): void {
        if (index < 0 || index >= editor.apps.length) throw new Error("invariant: DockAppsEditor.removeAt: index outside the list")
        editor.changed(editor.apps.filter((a, i) => i !== index))
    }

    function addApp(id: string): void {
        if (id === "") throw new Error("invariant: DockAppsEditor.addApp: empty id")
        if (editor.apps.indexOf(id) >= 0) return
        editor.changed(editor.apps.concat([id]))
    }

    Repeater {
        model: editor.apps
        delegate: Row {
            id: line
            required property string modelData
            required property int index
            readonly property bool known: !!editor.entryOf(line.modelData)
            spacing: 10
            height: 40

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                source: editor.iconOf(line.modelData)
                sourceSize: Qt.size(56, 56)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 240
                elide: Text.ElideRight
                text: editor.nameOf(line.modelData) + (line.known ? "" : "  (not installed)")
                color: line.known ? Tokens.ink : Tokens.inkFaint
            }
            ActionButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 34
                active: line.index > 0
                text: "Up"
                onClicked: editor.shift(line.index, -1)
            }
            ActionButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 34
                active: line.index < editor.apps.length - 1
                text: "Down"
                onClicked: editor.shift(line.index, 1)
            }
            ActionButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 34
                text: "Remove"
                onClicked: editor.removeAt(line.index)
            }
        }
    }

    Label {
        visible: editor.apps.length === 0
        text: "No apps yet. The dock then shows only the apps that are open."
        color: Tokens.inkFaint
    }

    ActionButton {
        implicitHeight: 34
        text: editor.picking ? "Done" : "Add app"
        onClicked: { editor.picking = !editor.picking; editor.filter = "" }
    }

    // Picker: a search field over the installed apps.
    Column {
        visible: editor.picking
        width: 420
        spacing: 6

        FieldBox {
            width: parent.width
            placeholder: "Search apps"
            text: editor.filter
            onEdited: value => editor.filter = value
        }
        ListView {
            id: pickList
            width: parent.width
            height: Math.min(contentHeight, 240)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: editor.picking ? editor.installedApps() : []
            delegate: Item {
                id: pick
                required property var modelData
                width: pickList.width
                height: 38
                Rectangle { anchors.fill: parent; radius: 8; color: Tokens.ink; opacity: pickArea.containsMouse ? 0.06 : 0 }
                Image {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    width: 24
                    height: 24
                    source: pick.modelData.icon ? Quickshell.iconPath(pick.modelData.icon, true) : ""
                    sourceSize: Qt.size(48, 48)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Label { anchors { left: parent.left; leftMargin: 44; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } elide: Text.ElideRight; text: pick.modelData.name }
                MouseArea { id: pickArea; anchors.fill: parent; hoverEnabled: true; onClicked: editor.addApp(pick.modelData.id) }
            }
        }
    }

    Label {
        text: "Right-click an app in the dock to keep or remove it there as well."
        color: Tokens.inkFaint
    }
}
