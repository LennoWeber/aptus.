pragma Singleton
// Switcher: Alt+Tab logic: MRU order, the 150 ms threshold, commit.
// Owner: S7. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // window addresses, most recent first
    property var mru: []

    // Alt+Tab: first press arms the 150 ms threshold, later presses move the selection.
    function next(): void { Log.info("service.switcher", "next: not available yet"); }
    function previous(): void { Log.info("service.switcher", "previous: not available yet"); }
    // Alt released: focus the selected window and close.
    function commit(): void { Log.info("service.switcher", "commit: not available yet"); }
    // Esc / click outside: close without switching.
    function cancel(): void { Log.info("service.switcher", "cancel: not available yet"); }
}
