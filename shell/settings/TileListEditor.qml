pragma ComponentBehavior: Bound
import QtQuick
import qs.controlcenter
import qs.theme
import qs.components

// Editor for the control center tiles: order and visibility, per row a switch and Up/Down buttons.
Column {
    id: editor

    property var tiles: []   // saved order: { key, visible }
    signal changed(var tiles)

    readonly property var items: TileCatalog.normalize(tiles)

    spacing: 4

    function titleOf(key: string): string {
        const e = TileCatalog.entries.find(x => x.key === key)
        return e ? e.title : key
    }

    function setVisible(index: int, on: bool): void {
        editor.changed(editor.items.map((it, i) => i === index ? { key: it.key, visible: on } : it))
    }

    function shift(index: int, delta: int): void {
        const next = editor.items.slice()
        const target = index + delta
        if (target < 0 || target >= next.length) return
        const moved = next.splice(index, 1)[0]
        next.splice(target, 0, moved)
        editor.changed(next)
    }

    Repeater {
        model: editor.items
        delegate: Row {
            id: line
            required property var modelData
            required property int index
            spacing: 8
            height: 40

            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                width: 260
                label: editor.titleOf(line.modelData.key)
                checked: line.modelData.visible
                onToggled: on => editor.setVisible(line.index, on)
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
                active: line.index < editor.items.length - 1
                text: "Down"
                onClicked: editor.shift(line.index, 1)
            }
        }
    }
    Label {
        text: "Tiles are placed in this order, each in the first free spot."
        color: Tokens.inkFaint
    }
}
