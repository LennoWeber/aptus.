import QtQuick
import qs.theme
import qs.services
import qs.lock

// The keyboard itself. `standalone` is the separate keyboard window (for fields in windows that do not draw one);
// otherwise it sits inside a full-screen overlay (launcher, control center) that would hide a separate window.
Item {
    id: panel

    property bool standalone
    readonly property bool wanted: standalone ? Osk.shown && Osk.hosts.indexOf(Osk.targetWindow) < 0 : Osk.hostedBy(Window.window)
    property real progress: wanted ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    Component.onCompleted: if (!standalone) Osk.registerHost(Window.window)

    implicitWidth: 860
    implicitHeight: keys.implicitHeight + 28
    width: implicitWidth
    height: implicitHeight
    visible: progress > 0.001
    opacity: progress
    transform: Translate { y: (1 - panel.progress) * 40 }

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: -20
        radius: 18
        color: Tokens.surface
        border.width: 1
        border.color: Tokens.line
    }
    MouseArea { anchors.fill: parent }  // taps between the keys do nothing and do not fall through

    OnScreenKeyboard {
        id: keys
        anchors { fill: parent; margins: 14 }
        closable: true
        onKeyPressed: key => Osk.type(key)
        onBackspace: Osk.backspace()
        onEnter: Osk.enter()
        onShiftToggled: shifted = !shifted
        onCloseRequested: Osk.dismiss()
    }
}
