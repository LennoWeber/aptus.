import QtQuick
import Quickshell
import qs.models

// Timer and pomodoro. The end time is kept as a clock time, so a late tick never makes it drift.
Scope {
    id: root

    property int mode                // Enums.TimerMode
    property bool running
    property int totalSec
    property int remainingSec
    property int pomodoroPhase       // 0 = work, 1 = short break, 2 = long break
    property int pomodoroRound: 1    // 1..4
    property int workSec: 1500
    property int shortBreakSec: 300
    property int longBreakSec: 900
    readonly property bool idle: !running && remainingSec <= 0
    readonly property real progress: totalSec > 0 ? 1 - remainingSec / totalSec : 0
    readonly property string phaseName: mode === Enums.TimerMode.Pomodoro ? ["Focus", "Short break", "Long break"][pomodoroPhase] : "Timer"
    signal finished(string label)

    property double endMs: 0

    function format(seconds: int): string {
        const s = Math.max(0, seconds)
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const sec = s % 60
        const mm = (h > 0 && m < 10 ? "0" : "") + m
        return (h > 0 ? h + ":" : "") + mm + ":" + (sec < 10 ? "0" : "") + sec
    }

    function begin(seconds: int): void {
        totalSec = seconds
        remainingSec = seconds
        endMs = Date.now() + seconds * 1000
        running = true
    }

    function startTimer(seconds: int): void {
        if (!Number.isInteger(seconds) || seconds < 1 || seconds > 86400) throw new Error("invariant: TimerState.startTimer: seconds must be an integer between 1 and 86400")
        mode = Enums.TimerMode.Timer
        begin(seconds)
    }

    function startPomodoro(): void {
        if (workSec <= 0 || shortBreakSec <= 0 || longBreakSec <= 0) throw new Error("invariant: TimerState.startPomodoro: pomodoro durations must be positive")
        mode = Enums.TimerMode.Pomodoro
        pomodoroPhase = 0
        pomodoroRound = 1
        begin(workSec)
    }

    function pause(): void {
        if (!running) throw new Error("invariant: TimerState.pause: pause while not running")
        remainingSec = Math.max(0, Math.ceil((endMs - Date.now()) / 1000))
        running = false
    }

    function resume(): void {
        if (running) throw new Error("invariant: TimerState.resume: resume while already running")
        if (remainingSec <= 0) throw new Error("invariant: TimerState.resume: nothing left to resume")
        endMs = Date.now() + remainingSec * 1000
        running = true
    }

    function reset(): void {
        running = false
        remainingSec = 0
        totalSec = 0
        pomodoroPhase = 0
        pomodoroRound = 1
    }

    // The tile's play button: start the last kind, pause, or resume.
    function toggle(): void {
        if (running) pause()
        else if (remainingSec > 0) resume()
        else if (mode === Enums.TimerMode.Pomodoro) startPomodoro()
        else startTimer(totalSec > 0 ? totalSec : 300)
    }

    function advancePomodoro(): void {
        if (pomodoroPhase === 0) {
            const long = pomodoroRound >= 4
            pomodoroPhase = long ? 2 : 1
            begin(long ? longBreakSec : shortBreakSec)
        } else {
            if (pomodoroPhase === 2) pomodoroRound = 1
            else pomodoroRound += 1
            pomodoroPhase = 0
            begin(workSec)
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.running
        onTriggered: {
            const left = Math.max(0, Math.ceil((root.endMs - Date.now()) / 1000))
            if (left !== root.remainingSec) root.remainingSec = left
            if (left > 0) return
            if (root.mode === Enums.TimerMode.Pomodoro) {
                const done = root.phaseName
                root.finished(done + " finished")
                Quickshell.execDetached(["notify-send", "-a", "shell.", "-i", "alarm-symbolic", done + " finished", root.pomodoroPhase === 0 ? "Time for a break." : "Back to focus."])
                root.advancePomodoro()
            } else {
                root.running = false
                root.finished("Timer finished")
                Quickshell.execDetached(["notify-send", "-a", "shell.", "-i", "alarm-symbolic", "Timer finished", root.format(root.totalSec) + " are over."])
            }
        }
    }
}
