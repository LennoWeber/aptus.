import QtQuick
import qs.theme

// A sample of one theme: its ground, its surface, its text colour and its accent, with the name below.
// Used by the theme picker (Super+T) and by the Theme row in Settings.
Item {
    id: swatch

    property string themeId
    property string label
    // { bg, surface, ink, accent } as colours; the theme's own, not the current theme's. For "auto" the dark half is
    // bg2, surface2 (the sample is split in two).
    property var colors: ({})
    property bool selected          // the theme in effect
    property bool highlighted       // the keyboard or pointer rests on it
    property bool busy              // the colours are being generated (theme wallpaper)

    signal chosen()
    signal hovered()

    implicitWidth: 96
    implicitHeight: 84

    readonly property bool split: colors.bg2 !== undefined

    Rectangle {
        id: sample
        width: parent.width
        height: 56
        radius: 12
        color: swatch.colors.bg || Tokens.surfaceAlt
        clip: true
        border.width: swatch.selected ? 2 : 1
        border.color: swatch.selected ? Tokens.ink : swatch.highlighted ? Tokens.inkFaint : Tokens.line
        Behavior on border.color { ColorAnimation { duration: Tokens.durFast } }
        scale: swatch.highlighted ? 1.0 : 0.97
        Behavior on scale { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

        // the second half of a split sample (auto: light and dark)
        Rectangle {
            visible: swatch.split
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: parent.width / 2
            color: swatch.colors.bg2 || "transparent"
        }
        // a card on the ground, a line of text on the card and the accent as a dot
        Rectangle {
            x: 10
            y: 12
            width: swatch.split ? parent.width - 20 : parent.width * 0.55
            height: 32
            radius: 7
            color: swatch.colors.surface || "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.06)
            Rectangle {
                x: 8
                y: 9
                width: 26
                height: 4
                radius: 2
                color: swatch.colors.ink || Tokens.ink
            }
            Rectangle {
                x: 8
                y: 18
                width: 16
                height: 4
                radius: 2
                color: swatch.colors.ink || Tokens.ink
                opacity: 0.45
            }
        }
        Rectangle {
            x: parent.width - width - 10
            y: parent.height - height - 10
            width: 14
            height: 14
            radius: 7
            visible: !swatch.split
            color: swatch.colors.accent || Tokens.inkFaint
        }
        // a quiet pulse while the colours are made
        Rectangle {
            anchors.fill: parent
            color: Tokens.surface
            opacity: 0
            visible: swatch.busy
            SequentialAnimation on opacity {
                running: swatch.busy
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 700; easing.type: Easing.InOutSine }
            }
        }
    }

    Text {
        anchors { top: sample.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: swatch.label
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.sizeBar
        font.weight: swatch.selected ? Font.DemiBold : Font.Normal
        color: swatch.selected || swatch.highlighted ? Tokens.ink : Tokens.inkSoft
        renderType: Text.NativeRendering
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: swatch.hovered()
        onClicked: swatch.chosen()
    }
}
