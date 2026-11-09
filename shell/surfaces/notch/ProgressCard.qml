// The progress card (surfaces/notch.md §5, 420 × 80): name, percent, rate and remaining if known;
// Cancel only when the source offers it.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // Set by the card host (ActivityCard).
    property string monitorName: ""
    property var activity: null
    property bool pinned: false
    // The Progress item shown.
    property var item: null

    // TODO(phase): name, percent, rate · remaining, Cancel (only when item.cancellable →
    //   Progress.cancel).
}
