// Downloads, copies, exports from notification hints (notch.md §4–§5).
// Owner: S3. Live while Progress has items; the compact look shows the first one.
import QtQuick
import qs.components

Activity {
    id: root

    activity: "progress"
    slot: "right"

    // The first Progress item (Progress.items[0]), or null.
    readonly property var item: null

    // No own right-click rows (notch.md §4: the menu is only Open in Today, which the Notch adds;
    // Cancel is on the card).
}
