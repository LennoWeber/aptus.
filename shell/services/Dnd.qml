pragma Singleton
// Dnd: do not disturb: modes, schedule, summary.
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): until S8 fills this service, each action method logs "not available yet"
    //   (category service.<name>) instead of throwing (phase-1 decision 6).

    // False until S8 fills this service; while false, Ipc answers "error: dnd is not available yet"
    // instead of "ok" (aptus msg exits non-zero).
    readonly property bool available: false

    property bool on: false
    // Date or null (until turned off)
    property var until: null

    // Super+Shift+D: until off, or off.
    function toggle(): void { throw new Error("Dnd.toggle: not implemented"); }
    function turnOn(): void { throw new Error("Dnd.turnOn: not implemented"); }
    function turnOff(): void { throw new Error("Dnd.turnOff: not implemented"); }
    // For a time (IPC `dnd for 1h`).
    function forSeconds(seconds: int): void { throw new Error("Dnd.forSeconds: not implemented"); }
    // Until a local time today or tomorrow (IPC `dnd until 18:00`).
    function untilTime(hhmm: string): void { throw new Error("Dnd.untilTime: not implemented"); }
}
