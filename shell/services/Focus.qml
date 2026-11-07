pragma Singleton
// Focus: focus state machine, log, stats, quiet bar.
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool running: false
    property bool paused: false
    // Date
    property var endsAt: null
    property string intent: ""
    // the bar is quiet (focus session or Super+Shift+B)
    property bool quietBar: false

    // "idle" | "focusing" | "paused" | "done" | "break" (surfaces/focus.md §1 state machine)
    property string state: "idle"
    // planned length of the running session, minutes (ring progress)
    property int plannedMinutes: 0
    // Date the session started
    property var startedAt: null

    // Super+Shift+F: the focus picker, or the focus card while a session runs (surfaces/focus.md §1).
    function shortcut(): void { throw new Error("Focus.shortcut: not implemented"); }
    function start(minutes: int, intent: var): void { throw new Error("Focus.start: not implemented"); }
    function stop(): void { throw new Error("Focus.stop: not implemented"); }
    function pause(): void { throw new Error("Focus.pause: not implemented"); }
    function resume(): void { throw new Error("Focus.resume: not implemented"); }
    function extend(minutes: int): void { throw new Error("Focus.extend: not implemented"); }
    // Super+Shift+B (surfaces/focus.md §4).
    function toggleQuietBar(): void { throw new Error("Focus.toggleQuietBar: not implemented"); }
}
