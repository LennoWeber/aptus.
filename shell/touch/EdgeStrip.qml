import QtQuick
import Quickshell

// Thin invisible strip at a screen edge for swipe gestures.
// Phase 2/3/4 skeleton. Body comes in phase 7.
PanelWindow {
    // TODO(phase 7): only takes touch input in the strip; a swipe longer than a threshold triggers the action.
    // TODO(phase 7): check in the prototype whether windows under the strip lose touches in an annoying way.

    property int edge  // Enums.Edge
    property int widthPx
    property string actionId
    signal swiped(int edge)
}
