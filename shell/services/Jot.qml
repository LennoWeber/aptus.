pragma Singleton
// Jot: inbox read/append/edit (jot.file).
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // resolved jot.file
    property string file: ""

    // Append a line to the inbox (IPC `jot add`).
    function add(text: string): void { throw new Error("Jot.add: not implemented"); }
    // Append a "- [ ] " line (IPC `jot todo`).
    function todo(text: string): void { throw new Error("Jot.todo: not implemented"); }
}
