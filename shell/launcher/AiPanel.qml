pragma ComponentBehavior: Bound
import QtQuick
import QtQml
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.models
import qs.theme
import qs.components
import qs.services

// Docked side panel for short AI questions: no blur, the rest of the screen stays usable.
// No tools and no history: the exchange is gone when the launcher closes.
PanelWindow {
    id: win

    property var launcherState  // LauncherState
    property var appSettings    // AppSettings

    readonly property bool shown: launcherState && launcherState.docked
    readonly property int edge: appSettings ? appSettings.aiDockEdge : Enums.DockEdge.Right
    readonly property int panelWidth: appSettings && appSettings.aiDockWidthPx > 0 ? appSettings.aiDockWidthPx : 420
    readonly property var provider: AiProviders.find(launcherState ? launcherState.activeProviderId : "")
    readonly property var messages: launcherState ? launcherState.chatMessages : []
    property real slide: shown ? 1 : 0   // 0 = off screen, 1 = in place
    // The parts settle one after the other: header and thread, then the input. Closing is quicker and all at once.
    property real headIn: shown ? 1 : 0
    property real inputIn: shown ? 1 : 0

    Behavior on slide { NumberAnimation { duration: win.shown ? Tokens.durSlow : Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    Behavior on headIn {
        SequentialAnimation {
            PauseAnimation { duration: win.shown ? 70 : 0 }
            NumberAnimation { duration: win.shown ? Tokens.durSlow : Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] }
        }
    }
    Behavior on inputIn {
        SequentialAnimation {
            PauseAnimation { duration: win.shown ? 130 : 0 }
            NumberAnimation { duration: win.shown ? Tokens.durSlow : Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] }
        }
    }

    function pickScreen(monitor: var): var {
        const list = Quickshell.screens
        if (monitor) for (const s of list) if (s.name === monitor.name) return s
        return list.length > 0 ? list[0] : null
    }

    function send(): void {
        const text = field.text.trim()
        if (text === "" || launcherState.busy || !provider) return
        field.text = ""
        launcherState.askAi(text)
    }

    screen: pickScreen(Hyprland.focusedMonitor)
    visible: shown || slide > 0.001
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: win.edge !== Enums.DockEdge.Bottom
        bottom: true
        left: win.edge === Enums.DockEdge.Left
        right: win.edge === Enums.DockEdge.Right
    }
    implicitWidth: win.panelWidth + 16
    implicitHeight: win.edge === Enums.DockEdge.Bottom ? 460 : 0
    // qmllint disable unqualified unresolved-type
    margins { top: Tokens.barHeight }
    // qmllint enable unqualified unresolved-type
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aptus-ai"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: if (shown) Qt.callLater(() => field.forceActiveFocus())

    Instantiator {
        model: 5
        delegate: Shortcut {
            required property int index
            enabled: win.shown
            sequence: (win.appSettings && win.appSettings.modeKeys && win.appSettings.modeKeys[index]) || ("Ctrl+" + (index + 1))
            onActivated: win.launcherState.setMode(index)
        }
    }

    Item {
        id: card
        width: win.panelWidth
        height: parent.height - 16
        // Glides in from beyond its edge (the window clips it) and fades in on the way.
        x: win.edge === Enums.DockEdge.Left ? 8 - (1 - win.slide) * (width + 16) : win.edge === Enums.DockEdge.Right ? parent.width - width - 8 + (1 - win.slide) * (width + 16) : (parent.width - width) / 2
        y: win.edge === Enums.DockEdge.Bottom ? parent.height - height - 8 + (1 - win.slide) * (height + 16) : 8
        opacity: Math.min(1, win.slide * 2)

        Surface {
            anchors.fill: parent
            cornerRadius: Tokens.radiusTile
            elevated: true
        }

        // Header: provider with arrows, clear, close.
        Item {
            id: header
            x: 16
            y: 10 + 10 * (1 - win.headIn)
            opacity: win.headIn
            width: parent.width - 32
            height: 32

            ModeGlyph {
                id: glyph
                anchors.verticalCenter: parent.verticalCenter
                mode: Enums.LauncherMode.Ai
                color: Tokens.inkSoft
            }
            Label {
                id: providerName
                anchors { left: glyph.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: win.provider ? win.provider.name : "No AI provider"
                font.weight: Font.DemiBold
            }
            Label {
                anchors { left: providerName.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                visible: AiProviders.enabledProviders().length > 1
                text: "Alt + ‹ ›"
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 4
                ActionButton {
                    text: "Clear"
                    implicitHeight: 28
                    active: win.messages.length > 0
                    onClicked: win.launcherState.clearChat()
                }
                ActionButton {
                    implicitHeight: 28
                    text: "Close"
                    onClicked: win.launcherState.hide()
                }
            }
        }
        Rectangle { id: rule; anchors.top: header.bottom; anchors.topMargin: 8; width: parent.width; height: 1; color: Tokens.line }

        Flickable {
            id: scroll
            anchors { top: rule.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: inputBox.top; bottomMargin: 8; leftMargin: 16; rightMargin: 16 }
            opacity: win.headIn
            contentWidth: width
            contentHeight: thread.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            onContentHeightChanged: if (contentHeight > height) contentY = contentHeight - height

            Column {
                id: thread
                width: scroll.width
                spacing: 12

                Label {
                    visible: win.messages.length === 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: win.provider ? "Ask a short question. Follow-ups work; nothing is kept after you close this." : "No AI provider is enabled. Add one in config/ai-providers.json."
                    color: Tokens.inkFaint
                }
                Repeater {
                    model: win.messages
                    delegate: Item {
                        id: msg
                        required property var modelData
                        width: thread.width
                        height: msg.modelData.fromUser ? bubble.height : answer.height

                        Rectangle {
                            id: bubble
                            visible: msg.modelData.fromUser
                            anchors.right: parent.right
                            width: Math.min(userText.implicitWidth + 24, parent.width * 0.85)
                            height: userText.implicitHeight + 16
                            radius: 12
                            color: Tokens.surfaceAlt
                            Label {
                                id: userText
                                anchors { fill: parent; margins: 8; leftMargin: 12; rightMargin: 12 }
                                text: msg.modelData.text
                                wrapMode: Text.Wrap
                            }
                        }
                        Label {
                            id: answer
                            visible: !msg.modelData.fromUser
                            width: parent.width
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            text: msg.modelData.error !== "" ? msg.modelData.error : (msg.modelData.text !== "" ? msg.modelData.text : "…")
                            color: msg.modelData.error !== "" ? Tokens.critical : (msg.modelData.text !== "" ? Tokens.ink : Tokens.inkFaint)
                        }
                    }
                }
            }
        }

        Item {
            id: inputBox
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12; bottomMargin: 12 - 12 * (1 - win.inputIn) }
            opacity: win.inputIn
            height: 44

            Surface {
                anchors.fill: parent
                cornerRadius: Tokens.radiusPill
            }
            TextInput {
                id: field
                anchors { left: parent.left; leftMargin: 18; right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                font.family: Tokens.fontUi
                font.pixelSize: 15
                color: Tokens.ink
                selectionColor: Tokens.surfaceAlt
                selectedTextColor: Tokens.ink
                clip: true
                focus: true
                enabled: !!win.provider
                onAccepted: win.send()
                Keys.onPressed: event => {
                    const lst = win.launcherState
                    if (event.key === Qt.Key_Escape) lst.hide()
                    else if (event.key === Qt.Key_Tab) lst.cycleMode(1)
                    else if (event.key === Qt.Key_Backtab) lst.cycleMode(-1)
                    else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Left) lst.cycleProvider(-1)
                    else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Right) lst.cycleProvider(1)
                    else return
                    event.accepted = true
                }

                Text {
                    visible: field.text === "" && !field.preeditText
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.launcherState && win.launcherState.busy ? "Thinking…" : "Ask a quick question"
                    font: field.font
                    color: Tokens.inkFaint
                }
            }
        }
    }
}
