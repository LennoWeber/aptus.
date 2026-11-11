// The Theme service's run bookkeeping and its answer to an outside render (wave-2 review 3, 4).
// Theme.qml is a Quickshell Singleton: each test loads its text as an Item (as mkmock.py does for
// the core singletons) against the mock Process, StdioCollector, Tokens and Config.
import QtQuick
import QtTest
import qs.core

TestCase {
    id: testCase
    name: "theme"

    property var theme: null
    property var proc: null

    function load(): var {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("../../shell/services/Theme.qml"), false);
        xhr.send();
        const text = xhr.responseText.replace("pragma Singleton\n", "").replace("import Quickshell\n", "")
            .replace(/\nSingleton \{/, "\nItem {");
        return Qt.createQmlObject(text, testCase, "Theme.qml");
    }
    function init() {
        theme = load();
        proc = theme.resources.find(o => o.command !== undefined && o.stdout !== undefined);
        verify(proc, "the Process");
    }
    function cleanup() {
        theme.destroy();
        theme = null;
    }

    function test_a_run_ends_with_stdout_and_exit_in_either_order() {
        theme._run();
        verify(theme.applying && proc.running);
        proc.stdout.text = '{"generation": 4, "failed": {}, "mode": "lease"}';
        proc.exited(0);
        proc.running = false;                       // after the exit: still waiting for stdout
        verify(theme.applying);
        proc.stdout.streamFinished();
        verify(!theme.applying);
        compare(theme.generation, 4);
        theme._run();
        proc.stdout.text = '{"generation": 5, "failed": {"kde": "dbus"}, "mode": "lease"}';
        proc.stdout.streamFinished();
        verify(theme.applying);
        proc.exited(0);
        proc.running = false;
        verify(!theme.applying);
        compare(theme.generation, 5);
        compare(theme.failed, { kde: "dbus" });
    }

    function test_a_program_that_cannot_start_ends_the_run() {
        // Quickshell 0.3.2 with a missing binary: `running` turns off, no exit, no end of stdout
        proc.stdout.text = '{"generation": 9}';      // a previous run's output must not count
        theme._run();
        verify(theme.applying);
        proc.running = false;
        verify(!theme.applying);
        verify(!theme.busy);
        compare(theme.failed, { render: "aptus-theme could not be started" });
        compare(theme.generation, 0);
    }

    function test_an_outside_render_requests_no_apply() {
        tryVerify(() => Tokens._r !== null);
        Tokens._external(JSON.stringify(Tokens._r));    // the first load only counts as seen
        const outside = JSON.parse(JSON.stringify(Tokens._r));
        outside.mode = outside.mode === "dark" ? "light" : "dark";
        outside.accentName = outside.accentName === "jade" ? "sky" : "jade";
        Tokens._external(JSON.stringify(outside));
        compare(Tokens.mode, outside.mode);
        verify(!Tokens.applyingExternal);
        verify(!theme.busy, "an apply now would paint the apps with Config's values again");
        Tokens.resolveNow();                            // the shell's own resolution: an apply
        verify(theme.busy);
    }
}
