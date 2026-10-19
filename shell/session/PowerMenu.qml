pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.components

// Power menu: lock, log out, restart, shut down. Never suspend or hibernate.
// Restart and shut down need a second tap, so one wrong touch cannot end the session.
PanelWindow {
    id: menu

    property var lockState  // LockState
    property bool shown
    property string armed   // id of the action waiting for its second tap
    property real progress: shown ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    function toggle(): void {
        if (shown) hide()
        else { armed = ""; shown = true }
    }

    function hide(): void {
        shown = false
        armed = ""
    }

    function run(id: string): void {
        if ((id === "restart" || id === "shutdown") && armed !== id) {
            armed = id
            armTimer.restart()
            return
        }
        hide()
        if (id === "lock") lockState.lock()
        else if (id === "logout") Session.logout()
        else if (id === "restart") Session.restart()
        else if (id === "shutdown") Session.shutdown()
    }

    readonly property var actions: [
        { id: "lock", label: "Lock", glyph: "lock" },
        { id: "logout", label: "Log out", glyph: "logout" },
        { id: "restart", label: "Restart", glyph: "restart" },
        { id: "shutdown", label: "Shut down", glyph: "power" }
    ]

    screen: {
        const m = Hyprland.focusedMonitor
        if (m) for (const s of Quickshell.screens) if (s.name === m.name) return s
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    visible: shown || progress > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aptus-session"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer { id: armTimer; interval: 4000; onTriggered: menu.armed = "" }

    Shortcut { sequence: "Escape"; enabled: menu.shown; onActivated: menu.hide() }

    Rectangle {
        anchors.fill: parent
        color: Tokens.bg
        opacity: Tokens.overlayDim * 2 * menu.progress
        MouseArea { anchors.fill: parent; onClicked: menu.hide() }
    }

    Surface {
        id: card
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 8 * (1 - menu.progress)
        width: row.implicitWidth + 40
        height: 168
        elevated: true
        opacity: menu.progress

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: menu.actions
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property bool armed: menu.armed === modelData.id
                    width: 112
                    height: 128

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Tokens.surfaceAlt
                        border.width: 1
                        border.color: cell.armed ? Tokens.critical : Tokens.line
                        opacity: tap.pressed ? 1 : tap.containsMouse ? 0.9 : 0.6
                        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                    }
                    StatusGlyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 34
                        kind: cell.modelData.glyph
                        width: 28
                        height: 28
                        color: cell.armed ? Tokens.critical : Tokens.ink
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 82
                        text: cell.armed ? "Tap again" : cell.modelData.label
                        color: cell.armed ? Tokens.critical : Tokens.ink
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: tap
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: menu.run(cell.modelData.id)
                    }
                }
            }
        }
    }
}
