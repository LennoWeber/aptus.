pragma Singleton
// Timers: timers, alarms, stopwatch (absolute end times).
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // [{ id, label, kind: "timer" | "alarm" | "stopwatch", endsAt: Date | null, startedAt: Date,
    //    durationMs, paused: bool, remainingMs, ringing: bool }]
    property var timers: []
    // the timer that rings now, or null
    property var ringing: null
    function add(label: string, durationMs: real): void { throw new Error("Timers.add: not implemented"); }
    function stop(id: string): void { throw new Error("Timers.stop: not implemented"); }
    function extend(id: string, ms: real): void { throw new Error("Timers.extend: not implemented"); }
    function togglePause(id: string): void { throw new Error("Timers.togglePause: not implemented"); }
}
