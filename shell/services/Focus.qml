pragma Singleton
// Focus: focus state machine, log, stats, quiet bar.
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // False until S8 fills this service; while false, Ipc answers "error: focus is not available yet"
    // instead of "ok" (aptus msg exits non-zero).
    readonly property bool available: false

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
    function shortcut(): void { Log.info("service.focus", "shortcut: not available yet"); }
    function start(minutes: int, intent: var): void { Log.info("service.focus", "start: not available yet"); }
    function stop(): void { Log.info("service.focus", "stop: not available yet"); }
    function pause(): void { Log.info("service.focus", "pause: not available yet"); }
    function resume(): void { Log.info("service.focus", "resume: not available yet"); }
    function extend(minutes: int): void { Log.info("service.focus", "extend: not available yet"); }
    // Super+Shift+B (surfaces/focus.md §4).
    function toggleQuietBar(): void { Log.info("service.focus", "toggleQuietBar: not available yet"); }
}
