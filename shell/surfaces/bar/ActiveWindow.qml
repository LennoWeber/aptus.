// The active window in the bar (surfaces/bar.md §4): app icon 16 · title in `bar` type, ink.sec,
// state glyphs after it; with no window the workspace's name. Title changes animate with M-03 and
// are throttled to 250 ms when they come faster than 4 a second.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The Hyprland monitor name of this bar.
    property string monitorName: ""
    // The focused window when it is on this monitor's active workspace (a Hypr window record), or null.
    property var window: null
    // What shows without a window: the active workspace's name ("" for none).
    property string fallback: ""
    // The most the title may take (bar.md §2: 420, 240 on a narrow monitor).
    property real maxWidth: 0

    // The title and icon on screen now and the title leaving (M-03).
    property string _title: ""
    property string _oldTitle: ""
    property string _icon: ""
    property string _appName: ""
    // The throttle state (bar.js): recent change times and when the shown title was set.
    property var _throttle: ({ changes: [], shownAt: 0 })
    // M-03 progress 0 → 1 of the current swap.
    property real _swap: 1

    // The window's title or class changed: show it now or after the throttle's delay.
    function _changed(): void { throw new Error("not implemented"); }
    // Swap to the pending title and icon (M-03).
    function _show(): void { throw new Error("not implemented"); }
    // The window menu below the title (bar.md §4) and what its rows do.
    function _menu(): void { throw new Error("not implemented"); }
    function _menuTriggered(row: var): void { throw new Error("not implemented"); }
}
