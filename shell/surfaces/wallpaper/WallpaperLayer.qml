// The wallpaper of one monitor on an aptus-wallpaper Background layer (surfaces/wallpaper.md §2).
// Owner: S1 (drawing), S10 (gallery preview hooks).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core

PanelWindow {
    id: root

    // TODO(phase): Background layer, namespace aptus-wallpaper, all edges, exclusiveZone -1, no input
    //   (empty mask); colour ground under two Images (current, next) with the M-28 crossfade.
    // TODO(phase): fill modes fill/fit/center/tile and focus; sourceSize = logical size × scale,
    //   asynchronous decode (the next image fades in only once ready).

    required property string monitorName
    // The image being shown and the one decoding behind it (M-28 crossfade).
    property string source: ""
    property string fill: "fill"
    property string focus: "center"

    // Private state.
    // Which of the two images is in front; the other decodes the next source (M-28).
    property bool _aFront: true
    // The screen's scale (sourceSize = logical size × scale).
    readonly property real _scale: 0
    // fill "center": the image at its native size.
    readonly property bool _native: false
    // Image alignment from `focus` (fill crops toward it).
    readonly property int _hAlign: 0
    readonly property int _vAlign: 0

    // Private helpers.
    // Image.fillMode for a wallpaper.fill value.
    function _modeFor(mode: string): int { throw new Error("WallpaperLayer._modeFor: not implemented"); }
    // Start decoding `path` in the back image.
    function _load(path: string): void { throw new Error("WallpaperLayer._load: not implemented"); }
    // The back image finished decoding: fade it in, then swap _aFront.
    function _ready(img: Image, front: bool): void { throw new Error("WallpaperLayer._ready: not implemented"); }
}
