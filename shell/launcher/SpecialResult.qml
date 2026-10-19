import QtQuick
import qs.models
import qs.theme
import qs.components

// Single large result (calculator, timer, system action).
Item {
    id: special

    property string title
    property string value
    property string hint

    implicitHeight: 96

    Surface {
        anchors.fill: parent
        cornerRadius: 18
        elevated: true

        Label {
            anchors { left: parent.left; leftMargin: 24; top: parent.top; topMargin: 14 }
            text: special.title
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }
        Label {
            anchors { left: parent.left; leftMargin: 24; bottom: parent.bottom; bottomMargin: 12 }
            text: special.value
            role: Enums.TextRole.Display
            tabularNumbers: true
        }
        Label {
            anchors { right: parent.right; rightMargin: 24; bottom: parent.bottom; bottomMargin: 16 }
            text: special.hint
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }
    }
}
