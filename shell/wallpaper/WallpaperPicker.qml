pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.models
import qs.theme
import qs.services
import qs.components

// Wallpaper picker on the same blurred background as the control center: a grid of thumbnails, a tap sets the
// picture at once, Esc or a tap outside closes.
PanelWindow {
    id: picker

    property bool isOpen
    property real blurAmount: isOpen ? 1 : 0
    Behavior on blurAmount { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    function show(): void {
        Wallpaper.scan()
        isOpen = true
    }

    function hide(): void {
        isOpen = false
    }

    function toggle(): void {
        if (isOpen) hide()
        else show()
    }

    screen: {
        const m = Hyprland.focusedMonitor
        if (m) for (const s of Quickshell.screens) if (s.name === m.name) return s
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    visible: isOpen || blurAmount > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aptus-wallpaper-picker"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property Item blurTarget: scrim
    // qmllint disable unresolved-type unqualified
    BackgroundEffect.blurRegion: Region { item: picker.blurTarget }
    // qmllint enable unresolved-type unqualified

    Shortcut { sequence: "Escape"; enabled: picker.isOpen; onActivated: picker.hide() }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Tokens.bg
        opacity: Tokens.overlayDim * 2 * picker.blurAmount
        MouseArea { anchors.fill: parent; onClicked: picker.hide() }
    }

    Surface {
        id: board
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 10 * (1 - picker.blurAmount)
        width: Math.min(parent.width - 80, 1000)
        // As high as the pictures need, up to the screen.
        height: Math.min(parent.height - 120, 150 + Math.ceil(grid.count / Math.max(1, Math.floor(grid.width / grid.cellWidth))) * grid.cellHeight)
        opacity: picker.blurAmount
        elevated: true
        cornerRadius: Tokens.radiusTile

        Label {
            id: title
            x: 24
            y: 20
            text: "Wallpaper"
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }
        Label {
            anchors { right: parent.right; rightMargin: 24; verticalCenter: title.verticalCenter }
            text: Wallpaper.folder.replace(Quickshell.env("HOME"), "~")
            color: Tokens.inkFaint
        }

        GridView {
            id: grid
            anchors { fill: parent; topMargin: 60; leftMargin: 18; rightMargin: 18; bottomMargin: 18 }
            cellWidth: width / Math.max(2, Math.floor(width / 230))
            cellHeight: cellWidth * 0.64
            clip: true
            // The first tile removes the wallpaper.
            model: [{ path: "", name: "None" }].concat(Wallpaper.list)

            delegate: Item {
                id: cell
                required property var modelData
                readonly property bool current: modelData.path === Wallpaper.current
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors { fill: parent; margins: 6 }
                    radius: 12
                    color: Tokens.surfaceAlt
                    border.width: cell.current ? 2 : 1
                    border.color: cell.current ? Tokens.ink : Tokens.line
                    clip: true

                    Image {
                        anchors { fill: parent; margins: 2 }
                        visible: cell.modelData.path !== ""
                        source: cell.modelData.path ? "file://" + cell.modelData.path : ""
                        sourceSize: Qt.size(460, 300)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: cell.modelData.path === ""
                        text: "None"
                        color: Tokens.inkSoft
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Tokens.ink
                        opacity: tap.pressed ? 0.14 : tap.containsMouse ? 0.06 : 0
                        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                    }
                    MouseArea {
                        id: tap
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Wallpaper.setWallpaper(cell.modelData.path)
                    }
                }
            }
        }

        Label {
            anchors.centerIn: parent
            visible: Wallpaper.list.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: "No pictures found.\nPut jpg, png or webp files into " + Wallpaper.folder.replace(Quickshell.env("HOME"), "~") + "\n(the folder can be changed in Settings, Appearance)."
            color: Tokens.inkSoft
        }
    }
}
