import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// Keyboard window for fields in windows that do not draw one (settings, AI panel): bottom centre, never takes focus.
PanelWindow {
    id: win

    screen: {
        const m = Hyprland.focusedMonitor
        if (m) for (const s of Quickshell.screens) if (s.name === m.name) return s
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    visible: panel.wanted || panel.progress > 0.001
    anchors { bottom: true }
    implicitWidth: panel.width
    implicitHeight: panel.height
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aptus-osk"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    OskPanel { id: panel; standalone: true }
}
