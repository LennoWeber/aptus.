import QtQuick
import qs.theme
import qs.components

// Content of the FocusTile. One tap toggles do-not-disturb.
Item {
    id: tile

    property bool expanded
    property var focusState

    readonly property bool on: focusState ? focusState.active : false

    StatusGlyph {
        kind: "focus"
        width: 24
        height: 24
        color: tile.on ? Tokens.bg : Tokens.inkSoft
    }
    Label {
        anchors { left: parent.left; bottom: parent.bottom }
        text: tile.on ? (tile.focusState.suppressedCount > 0 ? tile.focusState.suppressedCount + " held back" : "On") : "Off"
        font.weight: tile.on ? Font.DemiBold : Font.Normal
        color: tile.on ? Tokens.bg : Tokens.inkSoft
    }
    Rectangle {
        visible: tile.on
        anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 5 }
        width: 7
        height: 7
        radius: 3.5
        color: Qt.lighter(Tokens.ok, 1.6)
    }
}
