import QtQuick
import Quickshell
import qs.models

// On-screen indicator for volume, brightness and similar keys.
// Phase 2/3/4 skeleton. Body comes in phase 7.
PanelWindow {
    // TODO(phase 7): small opaque pill, appears in the same frame as the key press and fades after about a second.

    property int kind  // Enums.OsdKind
    property real level  // 0..1
    property bool muted

    function flash(newKind: int, newLevel: real, isMuted: bool): void {
        if (newKind < Enums.OsdKind.Volume || newKind > Enums.OsdKind.Caffeine) throw new Error("invariant: Osd.flash: unknown OSD kind")
        throw new Error("not implemented")
    }
}
