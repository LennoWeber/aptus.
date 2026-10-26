import QtQuick
import Quickshell
import qs.models
import qs.theme
import qs.components

// One app in the dock: icon, a dot for "running", a longer dot for "in front". The icon grows with `zoom` and
// stands on the bottom of the cell, so it rises out of the dock; the cell grows sideways with it.
Item {
    id: cell

    property var info             // { key, entry, pinned, windows }
    property int iconSize: 44
    property real zoom: 1             // 1 = rest size; grows near the pointer
    property bool bouncing            // the app was just started
    readonly property bool running: info ? info.windows.length > 0 : false
    readonly property bool front: info ? info.windows.some(w => w.activated) : false
    readonly property string name: info && info.entry ? info.entry.name : (info ? info.key : "")
    readonly property bool hovered: mouse.containsMouse
    // Rest size, times the zoom, and a little extra on hover when nothing zooms.
    readonly property real size: iconSize * zoom * (mouse.containsMouse && zoom < 1.01 ? 1.08 : 1) * (mouse.pressed ? 0.94 : 1)
    property real hop: 0              // lift while the app starts
    signal activated()
    signal menuRequested()

    width: size + 14
    height: iconSize + 18

    Behavior on zoom { NumberAnimation { duration: 70 } }

    Item {
        id: icon
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 + cell.hop }
        width: cell.size
        height: cell.size

        Image {
            id: img
            anchors.fill: parent
            source: cell.info && cell.info.entry && cell.info.entry.icon ? Quickshell.iconPath(cell.info.entry.icon, true) : ""
            sourceSize: Qt.size(cell.iconSize * 2.4, cell.iconSize * 2.4)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }
        // Without an icon: the first letter on a quiet tile.
        Rectangle {
            anchors.fill: parent
            visible: img.status !== Image.Ready
            radius: width * 0.22
            color: Tokens.surfaceAlt
            border.width: 1
            border.color: Tokens.line
            Label {
                anchors.centerIn: parent
                text: cell.name.length > 0 ? cell.name.charAt(0).toUpperCase() : "?"
                role: Enums.TextRole.Title
            }
        }
    }

    // Two hops, then rest, while the app starts.
    SequentialAnimation {
        running: cell.bouncing
        loops: Animation.Infinite
        onRunningChanged: if (!running) cell.hop = 0
        NumberAnimation { target: cell; property: "hop"; to: cell.iconSize * 0.4; duration: 260; easing.type: Easing.OutQuad }
        NumberAnimation { target: cell; property: "hop"; to: 0; duration: 260; easing.type: Easing.InQuad }
        PauseAnimation { duration: 120 }
    }

    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 3 }
        height: 4
        width: cell.front ? 14 : 4
        radius: 2
        color: Tokens.ink
        opacity: cell.running ? 1 : 0
        Behavior on width { NumberAnimation { duration: Tokens.durFast } }
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        pressAndHoldInterval: 500
        onClicked: m => { if (m.button === Qt.RightButton) cell.menuRequested(); else cell.activated() }
        onPressAndHold: cell.menuRequested()
    }
}
