// Swatch: Swatch (03 §9): a 20 px colour dot, ringed when selected.
import QtQuick
import qs.core

Item {
    id: root

    property color colour
    property bool selected: false
    // Tooltip text (the accent's name).
    property string name: ""
    signal picked()

    readonly property real _out: Tokens.swatch.ring + Tokens.swatch.ringGap

    implicitWidth: Tokens.swatch.size
    implicitHeight: Tokens.swatch.size
    Accessible.role: Accessible.RadioButton
    Accessible.name: name
    Accessible.checkable: true
    Accessible.checked: selected
    Accessible.onPressAction: root.picked()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.picked();
            event.accepted = true;
        }
    }

    // The ring: ink.main when selected, a faint ring under the pointer.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -root._out
        radius: width / 2
        color: "transparent"
        border.width: Tokens.swatch.ring
        border.color: root.selected ? Tokens.inkMain : Tokens.inkFaint
        opacity: root.selected || mouse.containsMouse ? 1 : 0

        Behavior on opacity {
            StandardAnimation { duration: Motion.ms("small", false) }
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.colour
    }
    MouseArea {
        id: mouse
        anchors.centerIn: parent
        width: Math.max(parent.width, Tokens.hitMin)
        height: width
        hoverEnabled: true
        onClicked: root.picked()
    }
    Tooltip {
        target: root
        text: root.name
        active: mouse.containsMouse
    }
}
