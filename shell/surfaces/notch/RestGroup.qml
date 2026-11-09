// The notch at rest (surfaces/notch.md §3): clock HH:mm (rolling minutes, M-34), the date 6 px
// after it, the unread dot 6 px after the date (M-35). Click: Today; right click: the DND / focus /
// calendar menu; hover: the long date as a tooltip.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The Hyprland monitor name (Today and the menu open there).
    property string monitorName: ""
    // bar.clock.showDate and not a narrow monitor.
    property bool showDate: true
    // Today has unread notifications; one of them is from an allowlisted app (accent dot).
    property bool unread: false
    property bool unreadAccent: false
    // A notch mode took the clock over (M-20): the clock hides while it is open.
    property bool clockTaken: false

    // The clock's rectangle in this item's coordinates (the Notch maps it for clockRect).
    readonly property rect clockRect: Qt.rect(0, 0, 0, 0)

    // The texts on screen, refreshed on the minute boundary (one aligned timer, 04 §8).
    property string _time: ""
    property string _date: ""
    property string _longDate: ""

    // Refresh the texts and arm the timer for the next minute boundary.
    function _refresh(): void { throw new Error("not implemented"); }
    // The right-click menu (notch.md §3) and what its rows do.
    function _menu(x: real, y: real): void { throw new Error("not implemented"); }
    function _menuTriggered(row: var): void { throw new Error("not implemented"); }
}
