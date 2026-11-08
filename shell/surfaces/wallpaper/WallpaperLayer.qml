// The wallpaper of one monitor on an aptus-wallpaper Background layer (surfaces/wallpaper.md §2).
// Owner: S1 (drawing), S10 (gallery preview hooks).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core

PanelWindow {
    id: root

    required property string monitorName
    // The image being shown and the one decoding behind it (M-28 crossfade).
    property string source: ""
    property string fill: "fill"
    property string focus: "center"

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "aptus-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {}
    color: Tokens.ground

    // Which of the two images is in front; the other decodes the next source (M-28).
    property bool _aFront: true
    // The screen's scale (sourceSize = logical size × scale).
    readonly property real _scale: screen ? screen.devicePixelRatio : 1
    // fill "center": the image at its native size.
    readonly property bool _native: fill === "center" || fill === "tile"
    // Image alignment from `focus` (fill crops toward it).
    readonly property int _hAlign: focus === "left" ? Image.AlignLeft : focus === "right" ? Image.AlignRight : Image.AlignHCenter
    readonly property int _vAlign: focus === "top" ? Image.AlignTop : focus === "bottom" ? Image.AlignBottom : Image.AlignVCenter

    // Image.fillMode for a wallpaper.fill value.
    function _modeFor(mode: string): int {
        return mode === "fit" ? Image.PreserveAspectFit : mode === "center" ? Image.Pad
             : mode === "tile" ? Image.Tile : Image.PreserveAspectCrop;
    }
    // Start decoding `path` in the back image.
    function _load(path: string): void {
        const url = Paths.url(path);
        if ((_aFront ? imgA : imgB).source.toString() === url) return;
        const back = _aFront ? imgB : imgA;
        back.opacity = 0;
        back.scale = 1.02;
        back.source = url;
    }
    // The back image finished decoding: fade it in, then swap _aFront.
    function _ready(img: Image, front: bool): void {
        if (img.status === Image.Ready && !front && img.source.toString() !== "") fadeIn.restart();
        else if (img.status === Image.Error) Log.warn("wallpaper", "cannot load " + img.source);
    }
    onSourceChanged: _load(source)
    Component.onCompleted: _load(source)

    // Two layers: the front image and the next one decoding behind it (M-28).
    Image {
        id: imgA
        anchors.fill: parent
        asynchronous: true
        cache: false
        smooth: true
        fillMode: root._modeFor(root.fill)
        // decode at the monitor's pixel size (wallpaper.md §2); native size for center and tile
        sourceSize: root._native ? undefined : Qt.size(root.width * root._scale, root.height * root._scale)
        horizontalAlignment: root._hAlign
        verticalAlignment: root._vAlign
        z: root._aFront ? 0 : 1
        onStatusChanged: root._ready(imgA, root._aFront)
    }
    Image {
        id: imgB
        anchors.fill: parent
        asynchronous: true
        cache: false
        smooth: true
        opacity: 0
        fillMode: root._modeFor(root.fill)
        // decode at the monitor's pixel size (wallpaper.md §2); native size for center and tile
        sourceSize: root._native ? undefined : Qt.size(root.width * root._scale, root.height * root._scale)
        horizontalAlignment: root._hAlign
        verticalAlignment: root._vAlign
        z: !root._aFront ? 0 : 1
        onStatusChanged: root._ready(imgB, !root._aFront)
    }

    ParallelAnimation {
        id: fadeIn
        readonly property Image target: root._aFront ? imgB : imgA
        NumberAnimation {
            target: fadeIn.target
            property: "opacity"
            to: 1
            duration: Motion.reduced ? Motion.reducedCrossfade : Motion.ambientWallpaper
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
        NumberAnimation {
            target: fadeIn.target
            property: "scale"
            to: 1
            duration: Motion.reduced ? 0 : Motion.ambientWallpaper
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
        onFinished: {
            const old = root._aFront ? imgA : imgB;
            root._aFront = !root._aFront;
            old.source = "";
            old.opacity = 0;
        }
    }
}
