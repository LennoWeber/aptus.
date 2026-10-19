import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.models

// Thin strip at a screen edge. A touch that starts in it and travels far enough inward is a swipe.
// The strip takes touch only; a mouse pointer passes through it.
PanelWindow {
    id: strip

    property int edge: Enums.Edge.Top  // Enums.Edge: Top or Left
    property int widthPx: 16
    readonly property int threshold: 60
    signal swiped(int edge)

    readonly property bool vertical: edge === Enums.Edge.Left || edge === Enums.Edge.Right

    anchors {
        top: strip.edge !== Enums.Edge.Bottom
        left: strip.edge !== Enums.Edge.Right
        right: strip.edge !== Enums.Edge.Left
        bottom: strip.edge !== Enums.Edge.Top
    }
    implicitWidth: vertical ? widthPx : 0
    implicitHeight: vertical ? 0 : widthPx
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aptus-edge"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    DragHandler {
        id: drag
        acceptedDevices: PointerDevice.TouchScreen
        target: null
        property bool fired
        onActiveChanged: if (!active) fired = false
        onTranslationChanged: {
            const travelled = strip.vertical ? (strip.edge === Enums.Edge.Left ? translation.x : -translation.x)
                                             : (strip.edge === Enums.Edge.Top ? translation.y : -translation.y)
            if (!fired && travelled > strip.threshold) {
                fired = true
                strip.swiped(strip.edge)
            }
        }
    }
}
