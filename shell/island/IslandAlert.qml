import QtQuick
import qs.models
import qs.theme
import qs.components

// The alert on the pill: a dot for how serious it is, the text, a line of detail. A card alert (music, mail,
// download, notification, timer, battery) grows the island and shows an AlertCard instead.
Item {
    id: alertView

    property var alert        // see IslandState.alert
    property var mediaState
    property color ink
    property color inkSoft
    property color line
    property real outerRadius: 22       // corner radius of the island body: inner shapes take outerRadius minus their margin
    property color accent
    property real cardWidth: 420

    readonly property bool isCard: alert !== null && alert !== undefined && alert.kind !== Enums.AlertKind.Plain
    readonly property real cardHeight: card.implicitHeight   // what the card wants, Island reads it to size the body

    signal clicked()
    signal dismissed()
    signal actionInvoked(string actionId)
    signal hoverChanged(bool hovered)

    // The card is wider than the body while it grows: what leaves the body is cut off.
    clip: isCard

    // One line that fills the pill: the dot on the left, the title next to it, the detail on the right (18 px from both edges).
    Item {
        visible: !alertView.isCard
        anchors { fill: parent; leftMargin: 18; rightMargin: 18 }

        Rectangle {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: alertView.alert && alertView.alert.severity !== Enums.Severity.Neutral ? Tokens.colorFor(alertView.alert.severity) : alertView.inkSoft
        }
        Label {
            anchors { left: dot.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
            width: Math.min(implicitWidth, parent.width - dot.width - 10 - (detail.visible ? detail.width + 12 : 0))
            text: alertView.alert ? alertView.alert.text : ""
            color: alertView.ink
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Label {
            id: detail
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: text !== ""
            width: Math.min(implicitWidth, parent.width * 0.4)
            text: alertView.alert ? alertView.alert.detail : ""
            color: alertView.inkSoft
            role: Enums.TextRole.Bar
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: !alertView.isCard
        onClicked: alertView.clicked()
    }

    AlertCard {
        id: card
        visible: alertView.isCard
        anchors.horizontalCenter: parent.horizontalCenter
        width: alertView.cardWidth
        outerRadius: alertView.outerRadius
        alert: alertView.isCard ? alertView.alert : null
        mediaState: alertView.mediaState
        ink: alertView.ink
        inkSoft: alertView.inkSoft
        line: alertView.line
        accent: alertView.accent
        onActivated: alertView.clicked()
        onDismissed: alertView.dismissed()
        onActionInvoked: id => alertView.actionInvoked(id)
        onHoverChanged: hovered => alertView.hoverChanged(hovered)
    }
}
