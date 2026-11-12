// The Theme service's run bookkeeping and its answer to an outside render (wave-2 review 3, 4).
// Theme.qml is a Quickshell Singleton: each test loads its text as an Item (as mkmock.py does for
// the core singletons) against the real Run (tst_run covers its Process handling) over the mock
// Process, and the real Tokens and Config.
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
        proc = theme.resources.find(o => o.start !== undefined && o._proc !== undefined);
        verify(proc, "the Run");
    }
    function cleanup() {
        theme.destroy();
        theme = null;
    }

    function test_a_run_reports_and_a_queued_one_follows() {
        theme._run();
        verify(theme.applying && proc.running);
        theme._run();                                   // during the run: once more after it
        verify(theme._queued);
        proc._proc.stdout.text = '{"generation": 4, "failed": {"kde": "dbus"}, "mode": "lease"}';
        proc._proc.exited(0);
        proc._proc.stdout.streamFinished();
        compare(theme.generation, 4);
        compare(theme.failed, { kde: "dbus" });
        verify(theme.applying && !theme._queued, "the queued run started");
    }

    function test_a_program_that_cannot_start_ends_the_run() {
        // Run reports code -1 (tst_run): Theme says why
        theme._run();
        verify(theme.applying);
        proc._proc.running = false;
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
        verify(!theme.busy, "an apply now would paint the apps with Config's values again");
        Tokens.resolveNow();                            // the shell's own resolution: an apply
        verify(theme.busy);
    }
}
