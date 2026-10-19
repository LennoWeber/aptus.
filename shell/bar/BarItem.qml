import QtQuick
import qs.models
import qs.theme
import qs.components

// One clickable item in the bar. Children go into the row after the optional text.
Item {
    id: item

    property string iconName
    property string text
    property int severity: Enums.Severity.Neutral  // Enums.Severity
    property int dropdownId: Enums.DropdownId.None // Enums.DropdownId
    property bool active
    property bool emphasis                         // semibold text (the wordmark)
    property int horizontalPadding: 8
    default property alias content: contentRow.data
    signal clicked()

    implicitWidth: contentRow.implicitWidth + 2 * horizontalPadding
    implicitHeight: Tokens.barHeight

    // Hover and press shape: a soft grey pill that grows in from a little smaller, never a colour.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: (parent.width - 2) * (0.88 + 0.12 * opacity / 0.14)
        height: parent.height - 6
        radius: 6
        color: Tokens.ink
        opacity: mouse.pressed ? 0.14 : (mouse.containsMouse || item.active) ? 0.09 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Label {
            visible: item.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: item.text
            role: Enums.TextRole.Bar
            tone: item.severity
            font.weight: item.emphasis ? Font.DemiBold : Font.Normal
        }
    }

    // The hit area is the whole bar height, larger than the visible shape.
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: item.clicked()
    }
}
