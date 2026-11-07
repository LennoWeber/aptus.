// The layers of one monitor (07-architecture §4): aptus-wallpaper (Background), aptus-reserve
// (Top, exclusive zone = bar height), aptus-shell (Overlay: frame, bar, notch, drawers, menus,
// passive content, capture overlay) and the stage-owned aptus-recframe. Created per screen by
// shell.qml; every surface it hosts comes from its stage folder, so stages never edit this file.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components

Scope {
    id: root

    // The screen (Variants model data).
    required property ShellScreen modelData
    // Notch-mode id → Component, from qs.registry NotchModes (passed in by shell.qml).
    property var notchModes: ({})
    // 0 → 1 during the session intro (M-01).
    property real introProgress: 1

    // The Hyprland monitor name of this screen.
    readonly property string name: modelData ? modelData.name : ""
    // This monitor's state in the SurfaceManager.
    readonly property MonitorState monitor: null
    // Whether this monitor's shell layer takes the keyboard (an interactive surface is open).
    readonly property bool keyboard: false
}
