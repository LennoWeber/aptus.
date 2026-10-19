import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import qs.theme
import qs.components

// The password prompt for system actions (pkexec, for example "use for login screen"). aptus registers as the
// session's polkit agent; if another agent already runs, registration fails and this stays hidden.
Scope {
    id: scope

    readonly property alias agent: agent

    PolkitAgent { id: agent }

    PanelWindow {
        id: win

        readonly property var flow: agent.flow

        screen: {
            const m = Hyprland.focusedMonitor
            if (m) for (const s of Quickshell.screens) if (s.name === m.name) return s
            return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        }
        visible: agent.isActive
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aptus-polkit"
        WlrLayershell.keyboardFocus: agent.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onFlowChanged: password.text = ""
        onVisibleChanged: if (visible) Qt.callLater(() => password.forceActiveFocus())

        function submit(): void {
            if (flow && flow.isResponseRequired) flow.submit(password.text)
            password.text = ""
        }
        function cancel(): void {
            if (flow) flow.cancelAuthenticationRequest()
        }

        Shortcut { sequence: "Escape"; enabled: agent.isActive; onActivated: win.cancel() }

        // Dim only, a blur here would hide what is being authorised.
        Rectangle {
            anchors.fill: parent
            color: Tokens.bg
            opacity: Tokens.overlayDim * 2
            MouseArea { anchors.fill: parent }
        }

        Surface {
            anchors.centerIn: parent
            width: 400
            height: column.implicitHeight + 40
            elevated: true
            cornerRadius: Tokens.radiusTile

            Column {
                id: column
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 12

                Label { text: "Authentication needed"; font.pixelSize: 17; font.weight: Font.DemiBold }
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: win.flow ? win.flow.message : ""
                    color: Tokens.inkSoft
                }

                Item {
                    visible: !!win.flow && win.flow.isResponseRequired
                    width: parent.width
                    height: 40
                    Surface { anchors.fill: parent; cornerRadius: 10 }
                    TextInput {
                        id: password
                        anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        font.family: Tokens.fontUi
                        font.pixelSize: 15
                        color: Tokens.ink
                        echoMode: win.flow && win.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        onAccepted: win.submit()
                        Text {
                            visible: password.text === "" && !password.preeditText
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.flow && win.flow.inputPrompt ? win.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
                            font: password.font
                            color: Tokens.inkFaint
                        }
                    }
                }

                Label {
                    visible: !!win.flow && win.flow.supplementaryMessage !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: win.flow ? win.flow.supplementaryMessage : ""
                    color: win.flow && win.flow.supplementaryIsError ? Tokens.critical : Tokens.inkSoft
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8
                    ActionButton { text: "Cancel"; onClicked: win.cancel() }
                    ActionButton { text: "Authenticate"; primary: true; onClicked: win.submit() }
                }
            }
        }
    }
}
