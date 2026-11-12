// The workspace strip keeps its pills across rebuilds (wave-2 review of S3, finding 2): Hypr
// hands a fresh strip record on every rebuild, the pills stay the same items, so the urgent
// nudge (M-36) fires on the urgent edge and only there. Runs against the mock import dir
// (tests/qml/mkmock.py; qs.services Hypr and Apps are doubles).
import QtQuick
import QtTest
import qs.core
import "../../shell/surfaces/bar" as Bar
import "../../shell/surfaces/bar/js/bar.js" as B

TestCase {
    id: testCase
    name: "workspacestrip"
    when: windowShown

    function rec(id: int, extra: var): var {
        const r = { id: id, name: "", label: String(id), monitor: "A", windows: 1, apps: ["kitty"], urgent: false,
                    special: false, active: false, focused: false };
        for (const k in extra) r[k] = extra[k];
        return r;
    }
    function strip(records: var): var { return { pills: records, scratch: null }; }

    Component {
        id: stripComponent
        Bar.WorkspaceStrip { monitorName: "A"; maxWidth: 1000 }
    }
    // The pills by workspace id (WorkspacePill items under the strip).
    function pillsOf(item: Item): var {
        const out = {};
        const walk = it => {
            for (const c of it.children) {
                if (c.nudge !== undefined && c.workspace !== undefined && !c.scratch) out[c.workspace.id] = c;
                walk(c);
            }
        };
        walk(item);
        return out;
    }

    ListModel { id: model }
    function ids(): var {
        const out = [];
        for (let i = 0; i < model.count; i++) out.push(model.get(i).wsId);
        return out;
    }

    function test_sync_ids_in_place() {
        model.clear();
        B.syncIds(model, [1, 2, 3]);
        compare(ids(), [1, 2, 3]);
        B.syncIds(model, [3, 1, 4]);
        compare(ids(), [3, 1, 4]);
        B.syncIds(model, [-98, 3]);
        compare(ids(), [-98, 3]);
        B.syncIds(model, []);
        compare(model.count, 0);
    }

    function test_pills_survive_a_rebuild_and_nudge_on_the_urgent_edge() {
        const s = createTemporaryObject(stripComponent, testCase, { strip: strip([rec(1, { active: true }), rec(2, {})]) });
        verify(s);
        const before = pillsOf(s);
        verify(before[1] && before[2], "two pills");
        compare(before[2]._nudge._last, 0);
        // a rebuild with fresh records (as Hypr.stripFor hands them), workspace 2 now urgent
        s.strip = strip([rec(1, { active: true }), rec(2, { urgent: true })]);
        const after = pillsOf(s);
        verify(after[1] === before[1] && after[2] === before[2], "the same pills after a rebuild");
        verify(after[2]._nudge._last > 0, "the urgent edge nudges the pill");
        compare(after[1]._nudge._last, 0);
        // another rebuild while still urgent: no second nudge
        const at = after[2]._nudge._last;
        s.strip = strip([rec(1, { active: true, windows: 2 }), rec(2, { urgent: true })]);
        compare(pillsOf(s)[2], before[2]);
        compare(before[2]._nudge._last, at);
        // a new workspace adds a pill, the others stay; one that leaves takes only its own
        s.strip = strip([rec(2, { urgent: true }), rec(3, {})]);
        const third = pillsOf(s);
        verify(third[2] === before[2] && third[3] !== undefined && third[1] === undefined);
    }
}
