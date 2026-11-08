pragma Singleton
// Jot: inbox read/append/edit (jot.file).
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // False until S8 fills this service; while false, Ipc answers "error: jot is not available yet"
    // instead of "ok" (aptus msg exits non-zero).
    readonly property bool available: false

    // resolved jot.file
    property string file: ""

    // Append a line to the inbox (IPC `jot add`).
    function add(text: string): void { Log.info("service.jot", "add: not available yet"); }
    // Append a "- [ ] " line (IPC `jot todo`).
    function todo(text: string): void { Log.info("service.jot", "todo: not available yet"); }
}
