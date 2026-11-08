// EmptyState: Empty state (03 §9): glyph 40 in faint, one line sec, optional action.
import QtQuick
import qs.core

Item {
    id: root

    property string glyph: ""
    property string text: ""
    property string actionText: ""
    signal action()

    // From the parts' implicit sizes (not the Column's), so a narrower host can elide the line.
    implicitWidth: Math.max(icon.visible ? icon.width : 0, line.implicitWidth, button.visible ? button.implicitWidth : 0)
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.centerIn: parent
        spacing: Tokens.s4

        Glyph {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.glyph !== ""
            name: root.glyph
            size: Tokens.emptyState.glyph
            colour: Tokens.inkFaint
        }
        Label {
            id: line
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, root.width)
            horizontalAlignment: Text.AlignHCenter
            text: root.text
            ink: "sec"
        }
        Button {
            id: button
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.actionText !== ""
            text: root.actionText
            variant: "plain"
            onClicked: root.action()
        }
    }
}
