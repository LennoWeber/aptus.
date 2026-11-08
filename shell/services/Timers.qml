pragma Singleton
// Timers: timers, alarms, stopwatch (absolute end times).
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // [{ id, label, kind: "timer" | "alarm" | "stopwatch", endsAt: Date | null, startedAt: Date,
    //    durationMs, paused: bool, remainingMs, ringing: bool }]
    property var timers: []
    // the timer that rings now, or null
    property var ringing: null
    function add(label: string, durationMs: real): void { Log.info("service.timers", "add: not available yet"); }
    function stop(id: string): void { Log.info("service.timers", "stop: not available yet"); }
    function extend(id: string, ms: real): void { Log.info("service.timers", "extend: not available yet"); }
    function togglePause(id: string): void { Log.info("service.timers", "togglePause: not available yet"); }
}
