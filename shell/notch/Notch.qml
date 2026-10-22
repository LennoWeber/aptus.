import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.models
import qs.theme
import qs.services
import qs.components

// The notch on one screen: a layer window of fixed size at the top centre (so the compositor never animates a
// resize). Only the notch inside it takes input; the rest of the window lets clicks through.
PanelWindow {
    id: win

    required property var modelData
    property var shellState         // ShellState
    property var appSettings        // AppSettings
    property var notchState         // NotchState
    property var audioState
    property var networkState
    property var bluetoothState
    property var batteryState
    property var nightLightState
    property var caffeineState
    property var focusState
    property var mediaState
    property var timerState
    property var captureState
    property var workspaces
    property string windowTitle
    property bool slidOut

    // Settings, as read from appSettings.
    readonly property string look: appSettings ? appSettings.get("notch.look") || "light" : "light"
    readonly property bool hoverOpen: appSettings ? appSettings.get("notch.hoverOpen") === true : false
    readonly property bool reserveSpace: appSettings ? appSettings.get("notch.reserveSpace") !== false : true
    readonly property bool mediaWings: appSettings ? appSettings.get("notch.mediaWings") !== false : true
    readonly property string clockFormat: appSettings ? appSettings.get("bar.clockFormat") || "24h" : "24h"

    // This screen's stage: Open only on the screen that was opened; an alert shows on every screen.
    readonly property int stage: {
        if (!notchState) return Enums.NotchStage.Rest
        if (notchState.stage === Enums.NotchStage.Open)
            return notchState.openScreen === modelData.name ? Enums.NotchStage.Open : (notchState.alert ? Enums.NotchStage.Alert : Enums.NotchStage.Rest)
        return notchState.stage
    }
    readonly property bool isOpen: stage === Enums.NotchStage.Open
    readonly property bool isAlert: stage === Enums.NotchStage.Alert
    readonly property bool inkLook: look === "ink" && !isOpen
    readonly property color fg: inkLook ? Tokens.bg : Tokens.ink
    readonly property color fgSoft: inkLook ? Qt.rgba(Tokens.bg.r, Tokens.bg.g, Tokens.bg.b, 0.65) : Tokens.inkSoft
    property real slide: slidOut ? 1 : 0
    Behavior on slide { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen, real offsetX)
    signal tileRequested(int tileId)
    signal controlCenterRequested()
    signal launcherRequested()

    screen: modelData
    anchors.top: true
    implicitWidth: 560
    implicitHeight: 380
    exclusiveZone: reserveSpace && !slidOut ? Tokens.topInset : 0
    color: "transparent"
    mask: Region { item: body }
    WlrLayershell.namespace: "aptus-notch"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Fullscreen windows and caffeine keep the screen awake (policy in Idle); the notch holds the inhibitor
    // while it is the top element, as the bar does.
    IdleInhibitor {
        enabled: Idle.inhibit
        window: win
    }

    // Click outside closes the open notch.
    HyprlandFocusGrab {
        windows: [win]
        active: win.isOpen
        onCleared: if (win.notchState) win.notchState.close()
    }

    // The size of the notch for each stage.
    readonly property real restWidth: 120 + 2 * rest.wingWidth
    readonly property real targetWidth: isOpen ? 520 : isAlert ? 380 : restWidth
    readonly property real targetHeight: isOpen ? sheet.implicitHeight + 6 : isAlert ? 38 : Tokens.barHeight

    NotchShape {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: -(height + 2) * win.slide
        width: win.targetWidth
        height: win.targetHeight
        cornerRadius: win.isOpen ? 22 : 14
        fill: win.isOpen ? Tokens.surface : (win.look === "ink" ? Tokens.ink : Tokens.surface)
        stroke: win.inkLook ? Tokens.ink : Tokens.line
        Behavior on width { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        Behavior on height { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        Behavior on cornerRadius { NumberAnimation { duration: Tokens.durSlow } }
        Behavior on fill { ColorAnimation { duration: Tokens.durSlow } }

        // Rest: tap opens.
        NotchRest {
            id: rest
            anchors.fill: parent
            opacity: !win.isOpen && !win.isAlert ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            mediaState: win.mediaState
            timerState: win.timerState
            captureState: win.captureState
            mediaWings: win.mediaWings
            clockFormat: win.clockFormat
            ink: win.fg
            inkSoft: win.fgSoft

            MouseArea {
                anchors.fill: parent
                onClicked: win.notchState.open(win.modelData.name)
            }
        }

        NotchAlert {
            anchors.fill: parent
            opacity: win.isAlert ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            alert: win.notchState ? win.notchState.alert : null
            ink: win.fg
            inkSoft: win.fgSoft
            onClicked: {
                const a = win.notchState.alert
                win.notchState.dismissAlert()
                if (a && a.tileId) win.tileRequested(a.tileId)
            }
        }

        FocusScope {
            anchors.fill: parent
            focus: win.isOpen
            opacity: win.isOpen ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            Keys.onEscapePressed: win.notchState.close()

            NotchSheet {
                id: sheet
                anchors.fill: parent
                appSettings: win.appSettings
                audioState: win.audioState
                networkState: win.networkState
                bluetoothState: win.bluetoothState
                batteryState: win.batteryState
                nightLightState: win.nightLightState
                caffeineState: win.caffeineState
                focusState: win.focusState
                mediaState: win.mediaState
                workspaces: win.workspaces
                clockFormat: win.clockFormat
                // The dropdown is placed first (it reads where the icon is), then the notch closes.
                onDropdownRequested: (id, anchor) => {
                    win.dropdownRequested(id, anchor, win.modelData, (win.modelData.width - win.width) / 2)
                    win.notchState.close()
                }
                onLauncherRequested: { win.notchState.close(); win.launcherRequested() }
                onControlCenterRequested: { win.notchState.close(); win.controlCenterRequested() }
            }
        }

        // Hover: with the setting on, resting on the notch for 300 ms opens it; leaving closes what hover opened.
        HoverHandler { id: hover }
    }

    property bool openedByHover
    Timer {
        interval: 300
        running: win.hoverOpen && hover.hovered && win.stage !== Enums.NotchStage.Open && win.notchState && win.notchState.enabled
        onTriggered: { win.notchState.open(win.modelData.name); win.openedByHover = true }
    }
    Timer {
        interval: 400
        running: win.openedByHover && win.isOpen && !hover.hovered
        onTriggered: { win.openedByHover = false; win.notchState.close() }
    }
    onIsOpenChanged: if (!isOpen) openedByHover = false
}
