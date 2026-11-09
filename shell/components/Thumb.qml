// Thumb: A rounded image thumbnail (wallpapers, screenshots, covers).
// `source` is a path or a URL; while it loads the raised wash shows, then the image fades in.
import QtQuick
import Quickshell.Widgets
import qs.core

Item {
    id: root

    property string source: ""
    property real radius: Tokens.windowRadius
    property bool selected: false

    readonly property real _out: Tokens.focusRingGap + Tokens.focusRingWidth

    Accessible.role: Accessible.Graphic

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: Tokens.raised

        Image {
            id: image
            anchors.fill: parent
            source: root.source === "" ? "" : root.source.charAt(0) === "/" ? Paths.url(root.source) : root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: root.width
            sourceSize.height: root.height
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                StandardAnimation { duration: Motion.ms("fade", false) }
            }
        }
    }
    // Selected: a 2 px accent ring 2 px outside, concentric (03 §6.3 geometry).
    Rectangle {
        anchors.fill: parent
        anchors.margins: -root._out
        radius: root.radius + root._out
        color: "transparent"
        border.width: Tokens.focusRingWidth
        border.color: Tokens.accent
        opacity: root.selected ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            StandardAnimation { duration: Motion.ms("small", !root.selected) }
        }
    }
}
