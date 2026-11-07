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
}
