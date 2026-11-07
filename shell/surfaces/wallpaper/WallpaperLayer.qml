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
}
