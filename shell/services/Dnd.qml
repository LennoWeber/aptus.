pragma Singleton
// Dnd: do not disturb: modes, schedule, summary.
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // False until S8 fills this service; while false, Ipc answers "error: dnd is not available yet"
    // instead of "ok" (aptus msg exits non-zero).
    readonly property bool available: false

    property bool on: false
    // Date or null (until turned off)
    property var until: null

    // Super+Shift+D: until off, or off.
    function toggle(): void { Log.info("service.dnd", "toggle: not available yet"); }
    function turnOn(): void { Log.info("service.dnd", "turnOn: not available yet"); }
    function turnOff(): void { Log.info("service.dnd", "turnOff: not available yet"); }
    // For a time (IPC `dnd for 1h`).
    function forSeconds(seconds: int): void { Log.info("service.dnd", "forSeconds: not available yet"); }
    // Until a local time today or tomorrow (IPC `dnd until 18:00`).
    function untilTime(hhmm: string): void { Log.info("service.dnd", "untilTime: not available yet"); }
}
