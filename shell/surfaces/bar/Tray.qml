// The tray (surfaces/bar.md §5): status-notifier items, 16 px, 6 apart, at most bar.tray.max
// visible, the rest behind an `expand_more` overflow menu; shown on the primary monitor only
// unless bar.tray.monitor is `all`.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The Hyprland monitor name of this bar.
    property string monitorName: ""
    // bar.tray.max (2 on a narrow monitor), bar.tray.hidden, bar.tray.order.
    property int maxItems: 3
    property var hiddenIds: []
    property var order: []
    // The tray shows on this monitor (bar.tray.monitor).
    property bool shown: true

    // The items in the bar and those behind the overflow button (bar.js trayLayout).
    readonly property var shownItems: []
    readonly property var overflowItems: []
}
