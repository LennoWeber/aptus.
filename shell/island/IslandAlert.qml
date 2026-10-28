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

    Row {
        visible: !alertView.isCard
        anchors.centerIn: parent
        spacing: 8
        width: Math.min(implicitWidth, alertView.width - 28)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: alertView.alert && alertView.alert.severity !== Enums.Severity.Neutral ? Tokens.colorFor(alertView.alert.severity) : alertView.inkSoft
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: alertView.alert ? alertView.alert.text : ""
            color: alertView.ink
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            width: Math.min(implicitWidth, alertView.width - 60)
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== "" && x + implicitWidth < alertView.width - 20
            text: alertView.alert ? alertView.alert.detail : ""
            color: alertView.inkSoft
            role: Enums.TextRole.Bar
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 150)
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
