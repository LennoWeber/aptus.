import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the NotificationsTile. The list itself arrives with the notification server.
Item {
    id: tile

    property bool expanded
    property int unreadCount

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            y: -4
            text: tile.unreadCount > 0 ? tile.unreadCount + "" : "0"
            role: Enums.TextRole.Display
            tabularNumbers: true
            color: tile.unreadCount > 0 ? Tokens.ink : Tokens.inkFaint
        }
        Label {
            anchors { left: parent.left; bottom: parent.bottom }
            text: tile.unreadCount > 0 ? "New notifications" : "All clear"
            color: Tokens.inkSoft
        }
    }

    Item {
        anchors.fill: parent
        visible: tile.expanded

        Label {
            anchors.centerIn: parent
            width: Math.min(parent.width, 420)
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: Tokens.inkSoft
            text: "No notifications."
        }
    }
}
