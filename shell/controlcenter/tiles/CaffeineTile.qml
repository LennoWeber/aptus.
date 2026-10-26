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
        color: tile.on ? Tokens.bg : Tokens.inkSoft
    }
    Label {
        anchors { left: parent.left; bottom: parent.bottom }
        text: tile.on ? "Awake" : "Off"
        font.weight: tile.on ? Font.DemiBold : Font.Normal
        color: tile.on ? Tokens.bg : Tokens.inkSoft
    }
    // Green dot beside the state: colour only as a small signal.
    Rectangle {
        visible: tile.on
        anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 5 }
        width: 7
        height: 7
        radius: 3.5
        color: Qt.lighter(Tokens.ok, 1.6)
    }
}
