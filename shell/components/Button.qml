// Button: Buttons (03 §9): primary (one per surface), plain, quiet, risk.
import QtQuick
import qs.core

Item {
    id: root

    property string text: ""
    // "primary" | "plain" | "quiet" | "risk"
    property string variant: "plain"
    property string glyph: ""
    property string tooltip: ""
    // Disabled with a reason: faint, no wash, but hover stays so the tooltip says why (03 §8);
    // use this instead of `enabled: false`, which also turns off hover.
    property string disabledReason: ""
    // Show the focus ring (set by the surface after keyboard navigation).
    property bool keyboardFocus: false
    signal clicked()

    readonly property bool _disabled: disabledReason !== ""
    readonly property bool _primary: variant === "primary"
    readonly property bool _quiet: variant === "quiet"
    readonly property bool _risk: variant === "risk"
    // risk buttons lead with the warning glyph (03 §2.5: colour is never the only signal)
    readonly property string _glyph: _risk && glyph === "" ? "warning" : glyph
    readonly property string _ink: !enabled || _disabled ? "faint" : _primary ? "onAccent" : _risk ? "crit" : _quiet ? "sec" : "main"
    readonly property color _fill: {
        const h = mouse.containsMouse && !_disabled, p = mouse.pressed && !_disabled;
        if (_primary) return p ? ComponentShared.layer(Tokens.accent, Tokens.onAccent, "pressed")
                             : h ? ComponentShared.layer(Tokens.accent, Tokens.onAccent, "hover") : Tokens.accent;
        if (_quiet) return p ? Tokens.washPressed : h ? Tokens.washHover : Tokens.alpha(Tokens.washHover, 0);
        return p ? Tokens.washPressed : h ? Tokens.raisedHot : Tokens.raised;
    }

    implicitHeight: _quiet ? Tokens.button.quietHeight : Tokens.button.height
    implicitWidth: Math.max(implicitHeight, (_glyph !== "" ? Tokens.glyphRow + content.spacing : 0)
                                             + (text !== "" ? label.implicitWidth : 0) + 2 * Tokens.button.padH)
    Accessible.role: Accessible.Button
    Accessible.name: text !== "" ? text : tooltip
    Accessible.description: disabledReason
    Accessible.onPressAction: if (!root._disabled) root.clicked()

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !root._disabled) {
            root.clicked();
            event.accepted = true;
        }
    }

    Item {
        id: face
        anchors.fill: parent
        // 03 §8: buttons from 32 px scale to 0.98 while pressed (60 ms)
        scale: mouse.pressed && !root._disabled && root.height >= Tokens.button.pressScaleMin ? Tokens.button.pressScale : 1

        Behavior on scale {
            StandardAnimation { duration: Motion.ms("press", !mouse.pressed) }
        }

        Rectangle {
            anchors.fill: parent
            radius: Tokens.button.radius
            color: root._fill

            Behavior on color {
                StandardColorAnimation { duration: mouse.pressed ? Motion.ms("press", false) : Motion.ms("hover", false) }
            }
        }
        Row {
            id: content
            anchors.centerIn: parent
            spacing: Tokens.s3

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: root._glyph !== ""
                name: root._glyph
                size: Tokens.glyphRow
                colour: ComponentShared.ink(root._ink)
            }
            Label {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                visible: root.text !== ""
                width: Math.min(implicitWidth, root.width - 2 * Tokens.button.padH - (root._glyph !== "" ? Tokens.glyphRow + content.spacing : 0))
                text: root.text
                type: "bodyStrong"
                ink: root._ink
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: if (!root._disabled) root.clicked()
    }
    FocusRing {
        target: root
        targetRadius: Tokens.button.radius
        shown: root.keyboardFocus
    }
    Tooltip {
        target: root
        text: root._disabled ? root.disabledReason : root.tooltip
        active: mouse.containsMouse && !mouse.pressed
    }
}
