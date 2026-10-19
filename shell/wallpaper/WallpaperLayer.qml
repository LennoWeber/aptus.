import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// The wallpaper behind everything, one per screen. A new picture fades in over the old one.
PanelWindow {
    id: layer

    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Tokens.bg
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "aptus-wallpaper"

    readonly property string url: Wallpaper.current ? "file://" + Wallpaper.current : ""

    Image {
        id: shown
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(layer.width, layer.height)
        source: layer.url
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durSlow } }
    }
}
