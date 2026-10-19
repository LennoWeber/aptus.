import QtQuick
import qs.theme

// Slider for volume, brightness, temperature.
Item {
    id: slider

    property real value
    property real from: 0
    property real to: 1
    property real step: 0
    property string iconName
    signal moved(real value)

    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    implicitWidth: 200
    implicitHeight: 36  // a large touch area around a thin track

    // Thin track, the filled part in ink, a round handle the finger can find.
    Rectangle {
        id: track
        x: 9
        width: parent.width - 18
        height: 4
        radius: 2
        anchors.verticalCenter: parent.verticalCenter
        color: Tokens.line

        Rectangle {
            width: slider.ratio * parent.width
            height: parent.height
            radius: 2
            color: Tokens.ink
        }
    }

    Rectangle {
        width: 18
        height: 18
        radius: 9
        anchors.verticalCenter: parent.verticalCenter
        x: track.x + slider.ratio * track.width - 9
        color: Tokens.surface
        border.width: 1.5
        border.color: Tokens.ink
        scale: area.pressed ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: Tokens.durFast } }
    }

    // The value applies live while dragging.
    MouseArea {
        id: area
        anchors.fill: parent
        function apply(x: real): void {
            const r = Math.max(0, Math.min(1, (x - track.x) / track.width))
            let v = slider.from + r * (slider.to - slider.from)
            if (slider.step > 0) v = Math.round(v / slider.step) * slider.step
            slider.moved(Math.max(slider.from, Math.min(slider.to, v)))
        }
        onPressed: mouse => apply(mouse.x)
        onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
    }
}
