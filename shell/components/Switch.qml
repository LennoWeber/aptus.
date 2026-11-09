// Switch: Switch (03 §9): 36 × 20 track, 16 thumb.
// Controlled: it emits toggled(new value) and the owner writes `checked`.
import QtQuick
import qs.core

Item {
    id: root

    property bool checked: false
    property string accessibleName: ""
    property bool keyboardFocus: false
    signal toggled(bool checked)

    readonly property real _inset: (height - Tokens.switchToken.thumb) / 2

    implicitWidth: Tokens.switchToken.width
    implicitHeight: Tokens.switchToken.height
    Accessible.role: Accessible.CheckBox
    Accessible.name: accessibleName
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onToggleAction: root.toggled(!root.checked)
    Accessible.onPressAction: root.toggled(!root.checked)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggled(!root.checked);
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Tokens.accent : Tokens.line

        Behavior on color {
            StandardColorAnimation { duration: Motion.ms("small", !root.checked) }
        }
    }
    Rectangle {
        width: Tokens.switchToken.thumb
        height: width
        radius: width / 2
        y: root._inset
        x: root.checked ? root.width - width - root._inset : root._inset
        color: !root.enabled ? Tokens.inkFaint : root.checked ? Tokens.onAccent : mouse.containsMouse ? Tokens.inkMain : Tokens.inkSec

        Behavior on x {
            enabled: !Motion.reduced
            SnappySpring {}
        }
        Behavior on color {
            StandardColorAnimation { duration: Motion.ms("small", !root.checked) }
        }
    }
    MouseArea {
        id: mouse
        anchors.centerIn: parent
        width: Math.max(parent.width, Tokens.hitMin)
        height: Math.max(parent.height, Tokens.hitMin)
        hoverEnabled: true
        onClicked: root.toggled(!root.checked)
    }
    FocusRing {
        target: root
        targetRadius: root.height / 2
        shown: root.keyboardFocus
    }
}
