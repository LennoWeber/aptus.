import QtQuick
import qs.models
import qs.theme
import qs.components

// The alert on the pill: a dot for how serious it is, the text, a line of detail.
Item {
    id: alertView

    property var alert        // see IslandState.alert
    property var mediaState
    property color ink
    property color inkSoft
    property color line
    property color accent
    property real cardWidth            // width of the card (px)
    property bool isCard               // the alert is not Plain: the card shows
    // TODO(phase 7, alerts): isCard = alert is not Plain; cardHeight = the card's implicitHeight (Island sizes the body from it).
    property real cardHeight           // what the card wants, Island reads it to size the body

    signal clicked()
    signal dismissed()
    signal actionInvoked(string actionId)
    signal hoverChanged(bool hovered)

    // TODO(phase 7, alerts): show AlertCard for every kind but Plain; Plain keeps this row.
    Row {
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
        onClicked: alertView.clicked()
    }
}
