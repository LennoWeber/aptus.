// Checkbox: Checkbox (03 §9): 18 × 18, radius 4, outline off, accent fill with a check glyph on.
// Controlled: it emits toggled(new value) and the owner writes `checked`.
import QtQuick
import qs.core

Item {
    id: root

    property bool checked: false
    property string accessibleName: ""
    property bool keyboardFocus: false
    signal toggled(bool checked)

    implicitWidth: Tokens.checkbox.size
    implicitHeight: Tokens.checkbox.size
    Accessible.role: Accessible.CheckBox
    Accessible.name: accessibleName
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onToggleAction: root.toggled(!root.checked)
    Accessible.onPressAction: root.toggled(!root.checked)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space) {
            root.toggled(!root.checked);
            event.accepted = true;
        }
    }

    // The hover wash covers the hit target, concentric with the box.
    Wash {
        anchors.centerIn: parent
        width: Math.max(parent.width, Tokens.hitMin)
        height: width
        radius: Tokens.checkbox.radius + (width - root.width) / 2
        hovered: mouse.containsMouse && root.enabled
        pressed: mouse.pressed
    }
    Rectangle {
        anchors.fill: parent
        radius: Tokens.checkbox.radius
        color: root.checked ? Tokens.accent : Tokens.alpha(Tokens.accent, 0)
        border.width: root.checked ? 0 : Tokens.checkbox.outline
        border.color: root.enabled ? Tokens.inkMeta : Tokens.inkFaint

        Behavior on color {
            StandardColorAnimation { duration: Motion.ms("small", !root.checked) }
        }
        Glyph {
            anchors.centerIn: parent
            name: "check"
            size: Tokens.glyphBar
            on: true
            active: true
            colour: Tokens.onAccent
            opacity: root.checked ? 1 : 0

            Behavior on opacity {
                StandardAnimation { duration: Motion.ms("small", !root.checked) }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.centerIn: parent
        width: Math.max(parent.width, Tokens.hitMin)
        height: width
        hoverEnabled: true
        onClicked: root.toggled(!root.checked)
    }
    FocusRing {
        target: root
        targetRadius: Tokens.checkbox.radius
        shown: root.keyboardFocus
    }
}
