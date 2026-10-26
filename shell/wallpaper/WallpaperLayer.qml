import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.models
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
        if (!(fit >= Enums.WallpaperFit.Fill && fit <= Enums.WallpaperFit.Tile)) throw new Error("invariant: WallpaperLayer.sourceSizeFor: unknown fit")
        return fit === Enums.WallpaperFit.Center || fit === Enums.WallpaperFit.Tile ? Qt.size(0, 0) : Qt.size(layer.width, layer.height)
    }

    Image {
        id: shown
        anchors.fill: parent
        fillMode: Tokens.fillModeFor(Wallpaper.fit)
        asynchronous: true
        sourceSize: layer.sourceSizeFor(Wallpaper.fit)
        source: layer.url
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durSlow } }
    }
}
