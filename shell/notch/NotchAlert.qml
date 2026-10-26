import QtQuick
import qs.models
import qs.theme
import qs.components

// The alert on the pill: a dot for how serious it is, the text, a line of detail.
Item {
    id: alertView

    property var alert        // { text, detail, severity }
    property color ink: Tokens.ink
    property color inkSoft: Tokens.inkSoft
    signal clicked()

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
