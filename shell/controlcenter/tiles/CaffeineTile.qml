import QtQuick
import qs.theme
import qs.components

// Content of the CaffeineTile. One tap toggles; manual only, no timer.
Item {
    id: tile

    property bool expanded
    property var caffeineState

    readonly property bool on: tile.caffeineState ? tile.caffeineState.active : false

    StatusGlyph {
        id: cup
        kind: "cup"
        width: 24
        height: 24
        color: tile.on ? Tokens.ok : Tokens.inkSoft
    }
    Label {
        anchors { left: parent.left; bottom: parent.bottom }
        text: tile.on ? "Awake" : "Off"
        font.weight: tile.on ? Font.DemiBold : Font.Normal
        color: tile.on ? Tokens.ok : Tokens.inkSoft
    }
}
