// IconButton: Icon-only button (03 §9): 28 (bar) or 32 (drawers), glyph 18, tooltip required.
import QtQuick
import qs.core

Item {
    id: root

    property string glyph: ""
    property string tooltip: ""
    // Disabled with a reason: faint, no wash, but hover stays so the tooltip says why (03 §8);
    // use this instead of `enabled: false`, which also turns off hover.
    property string disabledReason: ""
    // "bar" | "drawer"
    property string size: "drawer"
    property bool on: false
    property bool keyboardFocus: false
    signal clicked()
    signal rightClicked()
    signal middleClicked()

    readonly property bool _disabled: disabledReason !== ""

    implicitWidth: size === "bar" ? Tokens.iconButton.bar : Tokens.iconButton.drawer
    implicitHeight: implicitWidth
    Accessible.role: Accessible.Button
    Accessible.name: tooltip
    Accessible.description: disabledReason
    Accessible.checkable: on
    Accessible.onPressAction: if (!root._disabled) root.clicked()

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !root._disabled) {
            root.clicked();
            event.accepted = true;
        }
    }

    Item {
        anchors.fill: parent
        scale: mouse.pressed && !root._disabled && root.height >= Tokens.button.pressScaleMin ? Tokens.button.pressScale : 1

        Behavior on scale {
            NumberAnimation { duration: Motion.ms("press", !mouse.pressed); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard }
        }

        Wash {
            anchors.fill: parent
            radius: Tokens.iconButton.radius
            hovered: mouse.containsMouse && !root._disabled
            pressed: mouse.pressed && !root._disabled
            on: root.on
        }
        Glyph {
            anchors.centerIn: parent
            name: root.glyph
            size: Tokens.iconButton.glyph
            on: root.on
            colour: !root.enabled || root._disabled ? Tokens.inkFaint : root.on ? Tokens.accent : Tokens.inkMain
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => {
            if (root._disabled) return;
            if (event.button === Qt.RightButton) root.rightClicked();
            else if (event.button === Qt.MiddleButton) root.middleClicked();
            else root.clicked();
        }
    }
    FocusRing {
        target: root
        targetRadius: Tokens.iconButton.radius
        shown: root.keyboardFocus
    }
    Tooltip {
        target: root
        text: root._disabled ? root.disabledReason : root.tooltip
        active: mouse.containsMouse && !mouse.pressed
    }
}
