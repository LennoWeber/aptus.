pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.notifications
import qs.services

// Content of the NotificationsTile. Compact: unread count and the latest summary; expanded: the history.
Item {
    id: tile

    property bool expanded

    readonly property var list: Notifications.items
    readonly property int unread: Notifications.unreadCount

    // Opening the list reads everything.
    onExpandedChanged: if (expanded) Notifications.markAllRead()

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            y: -4
            text: tile.unread + ""
            role: Enums.TextRole.Display
            tabularNumbers: true
            color: tile.unread > 0 ? Tokens.ink : Tokens.inkFaint
        }
        Label {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            elide: Text.ElideRight
            text: tile.list.length > 0 ? tile.list[0].summary : (Notifications.doNotDisturb ? "Focus is on" : "All clear")
            color: Tokens.inkSoft
        }
    }

    Item {
        anchors.fill: parent
        visible: tile.expanded

        Label {
            anchors.centerIn: parent
            visible: tile.list.length === 0
            text: Notifications.doNotDisturb ? "No notifications. Focus is on." : "No notifications."
            color: Tokens.inkSoft
        }

        ActionButton {
            id: clearButton
            anchors { right: parent.right; top: parent.top }
            visible: tile.list.length > 0
            text: "Clear all"
            onClicked: Notifications.clearAll()
        }
        Label {
            anchors { left: parent.left; verticalCenter: clearButton.verticalCenter }
            visible: tile.list.length > 0
            text: tile.list.length + (tile.list.length === 1 ? " notification" : " notifications") + (Notifications.suppressedCount > 0 ? ", " + Notifications.suppressedCount + " held back" : "")
            color: Tokens.inkSoft
        }

        Flickable {
            anchors { left: parent.left; right: parent.right; top: clearButton.bottom; topMargin: 10; bottom: parent.bottom }
            contentHeight: stack.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: stack
                width: parent.width
                spacing: 8
                Repeater {
                    model: tile.list
                    delegate: NotificationCard {
                        required property var modelData
                        width: stack.width
                        item: modelData
                        onCloseRequested: Notifications.dismiss(modelData.id)
                        onActionInvoked: actionId => Notifications.invoke(modelData.id, actionId)
                    }
                }
            }
        }
    }
}
