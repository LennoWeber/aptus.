pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Category list: the active one is marked by weight and a quiet tint, not by colour.
Item {
    id: bar

    property var groups  // [{ group, categories: [{ id, title }] }]
    property string activeCategoryId
    signal categorySelected(string categoryId)

    Flickable {
        anchors { fill: parent; topMargin: 64; leftMargin: 12; rightMargin: 12; bottomMargin: 12 }
        contentWidth: width
        contentHeight: column.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width
            spacing: 2

            Repeater {
                model: bar.groups
                delegate: Column {
                    id: block
                    required property var modelData
                    required property int index
                    width: column.width
                    spacing: 2

                    Label {
                        topPadding: block.index === 0 ? 0 : 16
                        bottomPadding: 4
                        leftPadding: 14
                        text: block.modelData.group.toUpperCase()
                        role: Enums.TextRole.Bar
                        font.letterSpacing: 1
                        color: Tokens.inkFaint
                    }
                    Repeater {
                        model: block.modelData.categories
                        delegate: Item {
                            id: row
                            required property var modelData
                            readonly property bool active: row.modelData.id === bar.activeCategoryId
                            width: block.width
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
        }
    }
}
