import QtQuick
import qs.theme
import qs.components

// Bar with Save and Discard, visible only while there are unsaved changes.
Item {
    id: bar

    property bool hasUnsavedChanges
    property int changedCount
    signal saveRequested()
    signal discardRequested()

    implicitHeight: 64
    opacity: hasUnsavedChanges ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }

    Surface {
        anchors { fill: parent; margins: 10 }
        cornerRadius: Tokens.radiusTile
        elevated: true

        Label {
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            text: bar.changedCount + (bar.changedCount === 1 ? " unsaved change" : " unsaved changes")
        }
        Row {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8
            ActionButton { text: "Discard changes"; implicitHeight: 36; onClicked: bar.discardRequested() }
            ActionButton { text: "Save"; primary: true; implicitHeight: 36; onClicked: bar.saveRequested() }
        }
    }
}
