import QtQuick

// Small icon button with a larger touch target.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): visual size can be small, hit area at least minTargetPx; active state uses the ok colour.
    // TODO(phase 7): no hover-only feedback; the pressed state shows instantly.

    property string iconName
    property bool active
    property int severity  // Enums.Severity
    property string label
    property int minTargetPx
    signal clicked()
    signal pressAndHold()
}
