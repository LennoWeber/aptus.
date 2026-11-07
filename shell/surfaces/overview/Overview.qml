// The overview: the bar's lower edge drops into workspace cards (surfaces/overview.md §2).
// Owner: S7. Stub until its stage fills it.
import QtQuick
import qs.components

Drawer {
    id: root

    // M-14: the bar's workspace pills (Bar.pillRects), passed in by MonitorShell.
    property var pillRects: []
}
