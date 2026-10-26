import QtQuick
import qs.models
import qs.theme

// Generic row: title, subtitle, trailing text; the selected row carries a dot and a soft background.
Item {
    id: row

    property string title
    property string subtitle
    property string iconName
    property string trailing
    property bool selected
    property color dotColor: Tokens.ink
    property int severity  // Enums.Severity
    signal clicked()

    implicitWidth: 240
    implicitHeight: 40  // not below the touch target

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Tokens.surfaceAlt
        opacity: mouse.pressed ? 1 : (mouse.containsMouse || row.selected) ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
    }

    Rectangle {
        visible: row.selected
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 6
        height: 6
        radius: 3
        color: row.dotColor
    }

    Label {
        id: titleLabel
        anchors { left: parent.left; leftMargin: 26; verticalCenter: parent.verticalCenter }
        width: Math.min(implicitWidth, parent.width - 26 - trailingLabel.width - 16)
        elide: Text.ElideRight
        text: row.title
        tone: row.severity
        color: row.severity === Enums.Severity.Neutral ? Tokens.ink : Tokens.colorFor(row.severity)
    }

    Label {
        anchors { left: titleLabel.right; leftMargin: 8; right: trailingLabel.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        text: row.subtitle
        role: Enums.TextRole.Bar
        color: Tokens.inkFaint
    }

    Label {
        id: trailingLabel
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: row.trailing
        role: Enums.TextRole.Bar
        color: Tokens.inkSoft
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: row.clicked()
    }
}
