pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.components

// Pick the user; one user is shown as a plain name without choices.
Row {
    id: picker

    property var users: []
    property string selectedUser
    signal userSelected(string userName)

    spacing: 8

    Repeater {
        model: picker.users
        delegate: Item {
            id: cell
            required property var modelData
            readonly property bool current: modelData.name === picker.selectedUser
            width: nameLabel.implicitWidth + 28
            height: 40

            Rectangle {
                anchors.fill: parent
                radius: 20
                color: cell.current && picker.users.length > 1 ? Tokens.ink : "transparent"
                border.width: picker.users.length > 1 && !cell.current ? 1 : 0
                border.color: Tokens.line
            }
            Label {
                id: nameLabel
                anchors.centerIn: parent
                text: cell.modelData.displayName
                font.pixelSize: 17
                font.weight: Font.Medium
                color: cell.current && picker.users.length > 1 ? Tokens.bg : Tokens.ink
            }
            MouseArea {
                anchors.fill: parent
                enabled: picker.users.length > 1
                onClicked: picker.userSelected(cell.modelData.name)
            }
        }
    }
}
