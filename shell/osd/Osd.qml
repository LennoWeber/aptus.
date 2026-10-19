import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.models
import qs.theme
import qs.services
import qs.components

// On-screen indicator for volume, brightness and similar keys: a small opaque pill that appears in the same
// frame as the key press and fades after about a second. It never takes input.
PanelWindow {
    id: win

    property int kind  // Enums.OsdKind
    property real level  // 0..1
    property bool muted
    property string label  // text instead of the bar (caffeine, rotation)
    property bool shown
    property real fade: shown ? 1 : 0

    // No fade in (instant feedback), 140 ms fade out.
    Behavior on fade { enabled: !win.shown; NumberAnimation { duration: Tokens.durFast } }

    function flash(newKind: int, newLevel: real, isMuted: bool, newLabel: string): void {
        if (newKind < Enums.OsdKind.Volume || newKind > Enums.OsdKind.Caffeine) throw new Error("invariant: Osd.flash: unknown OSD kind")
        kind = newKind
        level = Math.max(0, Math.min(1, newLevel))
        muted = isMuted
        label = newLabel || ""
        shown = true
        hideTimer.restart()
    }

    function pickScreen(monitor: var): var {
        const list = Quickshell.screens
        if (monitor) for (const s of list) if (s.name === monitor.name) return s
        return list.length > 0 ? list[0] : null
    }

    readonly property string glyphKind: kind === Enums.OsdKind.Brightness ? "sun" : kind === Enums.OsdKind.Microphone ? "mic" : kind === Enums.OsdKind.Caffeine ? "cup" : kind === Enums.OsdKind.Rotation ? "rotate" : "volume"

    screen: pickScreen(Hyprland.focusedMonitor)
    visible: shown || fade > 0.01
    anchors { bottom: true }
    // qmllint disable unqualified unresolved-type
    margins { bottom: Osk.shown ? 340 : 84 }
    // qmllint enable unqualified unresolved-type
    implicitWidth: 280
    implicitHeight: 56
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aptus-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Timer {
        id: hideTimer
        interval: 1100
        onTriggered: win.shown = false
    }

    Surface {
        anchors.fill: parent
        cornerRadius: Tokens.radiusPill
        elevated: true
        opacity: win.fade

        StatusGlyph {
            x: 22
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            kind: win.glyphKind
            level: win.level
            muted: win.muted
            color: win.muted ? Tokens.critical : Tokens.ink
        }
        MeterBar {
            visible: win.label === ""
            anchors { left: parent.left; leftMargin: 56; right: parent.right; rightMargin: 64; verticalCenter: parent.verticalCenter }
            value: win.muted ? 0 : win.level
        }
        Label {
            visible: win.label === ""
            anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
            text: win.muted ? "Muted" : Math.round(win.level * 100) + "%"
            tabularNumbers: true
            color: win.muted ? Tokens.critical : Tokens.ink
        }
        Label {
            visible: win.label !== ""
            anchors { left: parent.left; leftMargin: 56; verticalCenter: parent.verticalCenter }
            text: win.label
            font.weight: Font.Medium
        }
    }
}
