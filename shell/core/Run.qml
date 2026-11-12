pragma ComponentBehavior: Bound
// One run of a program at a time, with Quickshell's Process quirks handled here once (found in
// the wave-2 review, Quickshell 0.3.2): stdout's end and the exit arrive in either order, and a
// program that cannot start (missing, not executable) only turns `running` off, with no exit and
// no end of stdout. `finished` comes once per run, after both, or with code -1 when it could not
// start (stdout and stderr "" then: an earlier run's output does not count).
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // The program and its arguments.
    property var command: []
    // A run was started and has not finished.
    readonly property bool running: _active

    signal finished(string stdout, string stderr, int code)

    // Start a run (nothing while one is running).
    function start(): void {
        if (_active) return;
        _done = {};
        _active = true;
        _proc.running = true;
    }

    property bool _active: false
    // What of the run is in: "out" (stdout ended), "exit" (its code).
    property var _done: ({})
    function _join(what: string, code: int): void {
        if (!_active) return;
        _done[what] = code;
        if ("out" in _done && "exit" in _done) _end(out.text, err.text, _done.exit);
    }
    function _end(stdout: string, stderr: string, code: int): void {
        _active = false;
        _done = {};
        finished(stdout, stderr, code);
    }

    readonly property Process _proc: Process {
        command: root.command
        stdout: StdioCollector {
            id: out
            onStreamFinished: root._join("out", 0)
        }
        stderr: StdioCollector { id: err }
    }
    readonly property Connections _events: Connections {
        target: root._proc
        function onExited(exitCode: int): void { root._join("exit", exitCode); }
        // a run that started has exited first
        function onRunningChanged(): void {
            if (!root._proc.running && root._active && !("exit" in root._done)) root._end("", "", -1);
        }
    }
}
