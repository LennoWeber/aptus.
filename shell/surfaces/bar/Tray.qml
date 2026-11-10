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
    property int maxItems: 0
    property var hiddenIds: []
    property var order: []
    // The tray shows on this monitor (bar.tray.monitor).
    property bool shown: true

    // The items in the bar and those behind the overflow button (bar.js trayLayout).
    readonly property var shownItems: []
    readonly property var overflowItems: []

    // The overflow menu (icon + title rows) below the `expand_more` button.
    function _overflowMenu(x: real, y: real): void { throw new Error("not implemented"); }
    // An overflow row: activate that item.
    function _overflowTriggered(row: var): void { throw new Error("not implemented"); }

    // TODO(phase): shownItems/overflowItems from bar.js trayLayout(SystemTray.items, maxItems,
    //   hiddenIds, order); a Row of TrayItem and the expand_more button (→ _overflowMenu).

    // Found by the probe (phase 5):
    // The items in the bar and those behind the overflow button (bar.js trayLayout).
    // TODO(phase): bar.js trayLayout(SystemTray.items.values, maxItems, hiddenIds, order).
    readonly property var _layout: ({ shown: [], overflow: [] })
    // TODO(phase): submenus come from a nested QsMenuOpener read when the menu opens; DBusMenu may
    //   load children lazily: checked with a real tray item, else the row opens the item's own menu.
}
