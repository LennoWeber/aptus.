pragma Singleton
// Jot: inbox read/append/edit (jot.file).
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): until S8 fills this service, each action method logs "not available yet"
    //   (category service.<name>) instead of throwing (phase-1 decision 6).

    // False until S8 fills this service; while false, Ipc answers "error: jot is not available yet"
    // instead of "ok" (aptus msg exits non-zero).
    readonly property bool available: false

    // resolved jot.file
    property string file: ""

    // Append a line to the inbox (IPC `jot add`).
    function add(text: string): void { throw new Error("Jot.add: not implemented"); }
    // Append a "- [ ] " line (IPC `jot todo`).
    function todo(text: string): void { throw new Error("Jot.todo: not implemented"); }
}
