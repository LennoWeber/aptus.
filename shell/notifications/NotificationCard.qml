pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.models
import qs.theme
import qs.components
import qs.services

// One notification: opaque card, app and time small, summary in weight, body below, actions as buttons.
Item {
    id: card

    property var item  // notification object from the Notifications service
    property bool popup  // true = floating popup (shadow, hover pauses the timeout)
    readonly property bool critical: item ? item.severity === Enums.Severity.Critical : false
    readonly property string iconSource: {
        if (!item) return ""
        if (item.image) return item.image
        if (!item.icon) return ""
        return item.icon.startsWith("/") ? "file://" + item.icon : Quickshell.iconPath(item.icon, true)
    }
    signal closeRequested()
    signal activated()
    signal actionInvoked(string actionId)

    implicitWidth: 360
    implicitHeight: column.implicitHeight + 28

    Surface {
        anchors.fill: parent
        cornerRadius: 14
        elevated: card.popup
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: card.activated()
        onContainsMouseChanged: if (card.popup && card.item) Notifications.setHovered(card.item.id, containsMouse)
    }

    // App icon, or the first letter when there is none.
    Item {
        id: iconBox
        x: 14
        y: 14
        width: 32
        height: 32
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Tokens.surfaceAlt
            visible: appIcon.status !== Image.Ready
            Label {
                anchors.centerIn: parent
                text: card.item && card.item.appName ? card.item.appName.charAt(0).toUpperCase() : "?"
                font.weight: Font.DemiBold
                color: Tokens.inkSoft
            }
        }
        Image {
            id: appIcon
            anchors.fill: parent
            source: card.iconSource
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }
    }

    Column {
        id: column
        x: 58
        y: 14
        width: card.width - 58 - 14
        spacing: 3

        Item {
            width: parent.width
            height: appLabel.implicitHeight
            Row {
                spacing: 6
                Rectangle {
                    visible: card.critical
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: Tokens.critical
                }
                Label {
                    id: appLabel
                    text: card.item ? card.item.appName : ""
                    role: Enums.TextRole.Bar
                    color: card.critical ? Tokens.critical : Tokens.inkFaint
                }
            }
            Label {
                anchors { right: parent.right; rightMargin: closeButton.visible ? 22 : 0 }
                text: card.item ? Qt.formatTime(card.item.timestamp, "hh:mm") : ""
                role: Enums.TextRole.Bar
                tabularNumbers: true
                color: Tokens.inkFaint
            }
        }

        Label {
            width: parent.width
            visible: text !== ""
            text: card.item ? card.item.summary : ""
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Label {
            width: parent.width
            visible: text !== ""
            text: card.item ? card.item.body : ""
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: card.popup ? 2 : 5
            elide: Text.ElideRight
            color: Tokens.inkSoft
        }

        Flow {
            width: parent.width
            spacing: 6
            visible: card.item && card.item.actions.length > 0
            Repeater {
                model: card.item ? card.item.actions : []
                delegate: ActionButton {
                    required property var modelData
                    implicitHeight: 32
                    text: modelData.label
                    onClicked: card.actionInvoked(modelData.id)
                }
            }
        }
    }

    // Close: dismisses for good. Shown on hover (always in the notification list).
    Item {
        id: closeButton
        visible: area.containsMouse || !card.popup
        anchors { right: parent.right; top: parent.top; rightMargin: 8; topMargin: 8 }
        width: 24
        height: 24
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Tokens.surfaceAlt
            opacity: closeArea.pressed ? 1 : closeArea.containsMouse ? 0.8 : 0
        }
        Repeater {
            model: 2
            delegate: Rectangle {
                required property int index
                anchors.centerIn: parent
                width: 10
                height: 1.5
                radius: 1
                rotation: index === 0 ? 45 : -45
                color: Tokens.inkSoft
            }
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: card.closeRequested()
        }
    }
}
