// core/Run.qml (wave-2 simplify A10): one `finished` per run whatever order Quickshell's Process
// reports stdout's end and the exit in, and code -1 for a program that cannot start. Runs against
// the mock Process and StdioCollector (tests/qml/mkmock.py), driven by hand.
import QtQuick
import QtTest
import qs.core

TestCase {
    id: testCase
    name: "run"

    Run { id: run; command: ["true"] }
    SignalSpy { id: spy; target: run; signalName: "finished" }

    function init() {
        spy.clear();
        run._proc.running = false;
        run._proc.stdout.text = "";
        run._proc.stderr.text = "";
    }
    function args(i: int): var { return Array.from(spy.signalArguments[i]); }

    function test_stdout_and_exit_in_either_order() {
        run.start();
        verify(run.running && run._proc.running);
        run._proc.stdout.text = "out 1";
        run._proc.stderr.text = "err 1";
        run._proc.exited(3);
        run._proc.running = false;                  // after the exit: still waiting for stdout
        compare(spy.count, 0);
        verify(run.running);
        run._proc.stdout.streamFinished();
        compare(spy.count, 1);
        compare(args(0), ["out 1", "err 1", 3]);
        verify(!run.running);
        run.start();
        run._proc.stdout.text = "out 2";
        run._proc.stderr.text = "";
        run._proc.stdout.streamFinished();
        compare(spy.count, 1, "stdout first: waits for the exit");
        run._proc.exited(0);
        compare(spy.count, 2);
        compare(args(1), ["out 2", "", 0]);
    }

    function test_a_program_that_cannot_start() {
        // Quickshell 0.3.2 with a missing binary: `running` turns off, no exit, no end of stdout
        run._proc.stdout.text = "an earlier run";   // does not count
        run.start();
        run._proc.running = false;
        compare(spy.count, 1);
        compare(args(0), ["", "", -1]);
        verify(!run.running);
    }

    function test_start_while_running_does_nothing() {
        run.start();
        run.start();
        run._proc.exited(0);
        run._proc.stdout.streamFinished();
        compare(spy.count, 1);
        run._proc.stdout.streamFinished();          // a stray end after the run: nothing
        run._proc.exited(0);
        compare(spy.count, 1);
    }
}
