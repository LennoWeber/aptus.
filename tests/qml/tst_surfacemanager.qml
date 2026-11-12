// SurfaceManager.qml itself (07 §5): the QML side around rules.js — snapshots, the lock path,
// monitors coming and going, fullscreen. Runs against the mock import dir (tests/qml/mkmock.py).
import QtQuick
import QtTest
import qs.core

TestCase {
    id: testCase
    name: "surfacemanager"

    function init() {
        SurfaceManager.locked = false;
        SurfaceManager.fullscreenMonitors = [];
        SurfaceManager.syncMonitors(["A", "B"]);
        SurfaceManager.activeMonitor = "A";
        for (const s of ["capture", "deck", "overview", "spotlight"]) {
            SurfaceManager.close(s, "A");
            SurfaceManager.close(s, "B");
        }
        SurfaceManager.closeMenu("A");
    }

    SignalSpy { id: passiveSpy; signalName: "passiveChanged" }
    SignalSpy { id: topSpy; signalName: "passiveTopChanged" }
    SignalSpy { id: pagesSpy; signalName: "deckPagesChanged" }

    function test_unchanged_fields_fire_nothing() {
        verify(SurfaceManager.post("toast", { text: "x" }, 1, "A", "") > 0);
        const m = SurfaceManager.monitors["A"];
        for (const spy of [passiveSpy, topSpy, pagesSpy]) { spy.target = m; spy.clear(); }
        SurfaceManager.close("overview", "B");                         // an operation that changes nothing on A
        compare(passiveSpy.count, 0);
        compare(topSpy.count, 0);
        compare(pagesSpy.count, 0);
        verify(SurfaceManager.post("toast", { text: "y" }, 1, "A", "") > 0);
        compare(passiveSpy.count, 1, "a real change still arrives");
        for (const e of m.passive.slice()) SurfaceManager.dismiss(e.id, "A");
        compare(m.passive.length, 0);
    }

    function test_event_ages_out_without_an_operation() {
        // an event queued behind a toast leaves after event.maxAgeMs by itself (the expiry timer)
        const toast = SurfaceManager.post("toast", { text: "t" }, 1, "A", "");
        SurfaceManager.post("event", { text: "e" }, 0, "A", "");
        const m = SurfaceManager.monitors["A"];
        compare(m.passive.length, 2);
        tryVerify(() => m.passive.length === 1, Tokens.surfaces.event.maxAgeMs + 2000);
        SurfaceManager.dismiss(toast, "A");
    }

    function test_lock_closes_menu_and_keeps_working() {
        SurfaceManager.openMenu("A", { anchorX: 0, anchorY: 0, owner: "t", model: [{ label: "X" }] });
        verify(SurfaceManager.monitors["A"].menu !== null);
        SurfaceManager.open("deck", {}, "B");
        SurfaceManager.locked = true;                                  // must not throw
        compare(SurfaceManager.monitors["A"].menu, null);
        verify(SurfaceManager.monitors["B"].deck, "the Deck stays under the lock");
        verify(SurfaceManager.post("osd", { kind: "volume", value: 0.5 }, 0, "A", "volume") > 0, "OSD on the lock screen");
        SurfaceManager.closeMenu("A");                                 // still works while locked
        compare(SurfaceManager.open("spotlight"), false, "opens are refused while locked");
        SurfaceManager.locked = false;
        verify(SurfaceManager.open("spotlight"));
    }
    function test_lock_closes_capture() {
        verify(SurfaceManager.open("capture", { mode: "region" }));
        verify(SurfaceManager.monitors["B"].capture !== null);
        SurfaceManager.locked = true;
        compare(SurfaceManager.monitors["A"].capture, null);
        compare(SurfaceManager.monitors["B"].capture, null);
    }
    function test_monitor_added_during_capture() {
        verify(SurfaceManager.open("capture", {}));
        SurfaceManager.syncMonitors(["A", "B", "C"]);
        compare(SurfaceManager.monitors["A"].capture, null);
        compare(SurfaceManager.monitors["C"].capture, null);
        SurfaceManager.syncMonitors(["A", "B"]);
        verify(!("C" in SurfaceManager.monitors));
    }
    function test_fullscreen_reaches_a_late_monitor() {
        SurfaceManager.fullscreenMonitors = ["D"];
        SurfaceManager.syncMonitors(["A", "B", "D"]);
        verify(SurfaceManager.monitors["D"].fullscreen);
        verify(!SurfaceManager.monitors["A"].fullscreen);
        SurfaceManager.fullscreenMonitors = [];
        verify(!SurfaceManager.monitors["D"].fullscreen);
        SurfaceManager.syncMonitors(["A", "B"]);
    }
    // Wave-2 simplify A1: an operation run from inside an apply (a field's change handler) starts
    // from the last result and applies in full; the outer apply stops writing instead of putting
    // its older fields back.
    property var nestedRun: null
    Connections {
        id: nest
        target: null
        function onPassiveChanged(): void {
            const f = testCase.nestedRun;
            testCase.nestedRun = null;
            if (f) f();
        }
    }
    function test_an_operation_inside_an_apply_wins() {
        const m = SurfaceManager.monitors["A"];
        const osd = SurfaceManager.post("osd", { kind: "volume", value: 0.4 }, 0, "A", "volume");
        compare(m.passiveTop.kind, "osd");
        nest.target = m;
        nestedRun = () => SurfaceManager.dismiss(osd, "A");      // runs when the toast's post writes `passive`
        const toast = SurfaceManager.post("toast", { text: "t" }, 1, "A", "");
        nest.target = null;
        verify(toast > osd, "post() still answers with its id");
        verify(!m.passive.some(e => e.id === osd), "the nested dismissal stays");
        compare(m.passiveTop.kind, "toast", "not the outer apply's OSD top");
        compare(m.passiveTop.entry.id, toast);
        compare(SurfaceManager._state.monitors["A"].passiveTop.kind, "toast");
        compare(SurfaceManager._state.monitors["A"].passive.length, m.passive.length);
        SurfaceManager.dismiss(toast, "A");
        compare(m.passive.length, 0);
    }
    function test_back_runs_the_registered_step_first() {
        let steps = 0;
        SurfaceManager.registerBack("A", "deck", () => { steps++; return steps === 1; });
        verify(SurfaceManager.open("deck"));
        SurfaceManager.back("A");
        verify(SurfaceManager.monitors["A"].deck, "the first Esc stepped back inside the Deck");
        SurfaceManager.back("A");
        verify(!SurfaceManager.monitors["A"].deck);
        SurfaceManager.unregisterBack("A", "deck");
    }
}
