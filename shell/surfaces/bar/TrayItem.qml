// One tray icon (surfaces/bar.md §5): click activates, right click opens its DBusMenu as an aptus
// menu, middle click is the secondary activation, the wheel scrolls; NeedsAttention shows a 6 px
// warn dot.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The Quickshell SystemTrayItem.
    property var item: null
    // The Hyprland monitor name of this bar (the menu opens there).
    property string monitorName: ""

    readonly property bool hovered: false

    // The item's DBusMenu as an aptus menu below the icon (QsMenuOpener rows → Menu model).
    function openMenu(): void { throw new Error("not implemented"); }
}
