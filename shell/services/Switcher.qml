pragma Singleton
// Switcher: Alt+Tab logic: MRU order, the 150 ms threshold, commit.
// Owner: S7. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): until S7 fills this service, each action method logs "not available yet"
    //   (category service.<name>) instead of throwing (phase-1 decision 6).

    // window addresses, most recent first
    property var mru: []

    // Alt+Tab: first press arms the 150 ms threshold, later presses move the selection.
    function next(): void { throw new Error("Switcher.next: not implemented"); }
    function previous(): void { throw new Error("Switcher.previous: not implemented"); }
    // Alt released: focus the selected window and close.
    function commit(): void { throw new Error("Switcher.commit: not implemented"); }
    // Esc / click outside: close without switching.
    function cancel(): void { throw new Error("Switcher.cancel: not implemented"); }
}
