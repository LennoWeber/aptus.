import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.models
import qs.theme
import qs.components

// Asks to keep the new settings. Always on top, big buttons, works with mouse and touch even if shortcuts break.
// Unanswered, the old settings come back when the countdown ends.
PanelWindow {
    id: win

    property int secondsLeft
    property bool isOpen
    signal confirmed()
    signal reverted()

    visible: isOpen
    color: "transparent"
    implicitWidth: 460
    implicitHeight: 210
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aptus-confirm"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Surface {
        anchors { fill: parent; margins: 10 }
        cornerRadius: Tokens.radiusTile
        elevated: true

        Label {
            id: title
            x: 24
            y: 22
            text: "Keep these settings?"
            role: Enums.TextRole.Title
        }
        Label {
            x: 24
            anchors.top: title.bottom
            anchors.topMargin: 6
            width: parent.width - 48
            wrapMode: Text.Wrap
            text: "The old settings come back in " + win.secondsLeft + " s."
            color: Tokens.inkSoft
            tone: win.secondsLeft <= 5 ? Enums.Severity.Warn : Enums.Severity.Neutral
        }
        Row {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20 }
            spacing: 12
            ActionButton { width: (parent.width - 12) / 2; implicitHeight: 52; text: "Revert now"; onClicked: win.reverted() }
            ActionButton { width: (parent.width - 12) / 2; implicitHeight: 52; text: "Keep"; primary: true; onClicked: win.confirmed() }
        }
    }
}
