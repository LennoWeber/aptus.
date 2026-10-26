import QtQuick
import Quickshell
import qs.models
import qs.theme
import qs.components

// One app in the dock: icon, a dot for "running", a longer dot for "in front".
Item {
    id: cell

    property var info             // { key, entry, pinned, windows }
    property int iconSize: 44
    readonly property bool running: info ? info.windows.length > 0 : false
    readonly property bool front: info ? info.windows.some(w => w.activated) : false
    readonly property string name: info && info.entry ? info.entry.name : (info ? info.key : "")
    readonly property bool hovered: mouse.containsMouse
    signal activated()
    signal menuRequested()

    width: iconSize + 14
    height: iconSize + 18

    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 2 }
        width: (cell.iconSize + 8) * (0.9 + 0.1 * opacity / 0.14)
        height: width
        radius: 12
        color: Tokens.ink
        opacity: mouse.pressed ? 0.14 : mouse.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    }

    Item {
        id: icon
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
        width: cell.iconSize
        height: cell.iconSize
        scale: mouse.pressed ? 0.92 : mouse.containsMouse ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

        Image {
            id: img
            anchors.fill: parent
            source: cell.info && cell.info.entry && cell.info.entry.icon ? Quickshell.iconPath(cell.info.entry.icon, true) : ""
            sourceSize: Qt.size(cell.iconSize * 2, cell.iconSize * 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }
        // Without an icon: the first letter on a quiet tile.
        Rectangle {
            anchors.fill: parent
            visible: img.status !== Image.Ready
            radius: 10
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
