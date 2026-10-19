pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.components

// Category list: the active one is marked by weight and a quiet tint, not by colour.
Item {
    id: bar

    property var categories  // { id, title }
    property string activeCategoryId
    signal categorySelected(string categoryId)

    Column {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 64 }
        spacing: 2

        Repeater {
            model: bar.categories
            delegate: Item {
                id: row
                required property var modelData
                readonly property bool active: row.modelData.id === bar.activeCategoryId
                width: parent.width
                height: 38

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Tokens.ink
                    opacity: row.active ? 0.08 : area.pressed ? 0.12 : area.containsMouse ? 0.05 : 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                }
                Label {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: row.modelData.title
                    font.weight: row.active ? Font.DemiBold : Font.Normal
                    color: row.active ? Tokens.ink : Tokens.inkSoft
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.categorySelected(row.modelData.id)
                }
            }
        }
    }
}
