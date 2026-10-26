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

    // The size the picture is decoded at: the screen for Fill, Fit and Stretch, its own size for Center and Tile.
    function sourceSizeFor(fit: int): size {
        throw new Error("not implemented")
    }

    Image {
        id: shown
        anchors.fill: parent
        // TODO(phase 7, themes): Tokens.fillModeFor(Wallpaper.fit); the bars of Fit and the gaps of Center show `color` (Tokens.bg).
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // TODO(phase 7, themes): sourceSizeFor(Wallpaper.fit) (Center and Tile must not be scaled to the screen); the horizontal/vertical alignment of Center is the middle.
        sourceSize: Qt.size(layer.width, layer.height)
        source: layer.url
        // TODO(phase 7, themes): a change of fit should not flash: keep the old picture until the new one is Ready (two Images, or Behavior on fillMode is not possible).
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durSlow } }
    }
}
