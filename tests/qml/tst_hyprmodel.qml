// The workspace model of the bar (services/js/hypr.js, bar.md §3, §8).
import QtQuick
import QtTest
import "../../shell/services/js/hypr.js" as H

TestCase {
    name: "hyprmodel"

    function win(address, cls, ws, focus) {
        return { address: address, "class": cls, title: cls, monitor: "eDP-1", workspace: ws, x: 0, y: 0, width: 10, height: 10,
                 floating: false, pinned: false, fullscreen: false, hidden: false, focusHistoryId: focus }
    }
    function records(urgent, names) {
        const ws = [{ id: 1, name: "1", monitor: "eDP-1" }, { id: 2, name: "web", monitor: "eDP-1" },
                    { id: 3, name: "3", monitor: "eDP-1" }, { id: -98, name: "special:scratch", monitor: "eDP-1" }]
        const windows = [win("0xa", "kitty", 1, 2), win("0xb", "firefox", 1, 0), win("0xc", "kitty", 1, 3),
                         win("0xd", "zen", 2, 1), win("0xe", "foot", -98, 4)]
        return H.workspaceRecords(ws, windows, [{ name: "eDP-1", activeWorkspace: 1 }], "eDP-1", ["0xc", "0xb"],
                                  urgent || [], names || {}, 12)
    }

    function test_fixed_ids_follow_the_script() {
        compare(H.fixedIds(["eDP-1"], "eDP-1"), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        compare(H.fixedIds(["eDP-1", "DP-3"], "DP-3"), [1, 2, 3, 4, 5])
        compare(H.fixedIds(["eDP-1", "DP-3"], "eDP-1"), [6, 7, 8, 9, 10])
        compare(H.fixedIds(["DP-2", "eDP-1", "DP-3"], "DP-3"), [])      // a third monitor has none
        compare(H.fixedIds(["DP-2"], "DP-2"), [1, 2, 3, 4, 5])
        compare(H.primary(["eDP-1"]), "eDP-1")
        compare(H.primary(["eDP-1", "DP-3"]), "DP-3")
        compare(H.primary(["DP-2", "eDP-1", "DP-3"]), "DP-2")
        compare(H.primary([]), "eDP-1")
        compare(H.address("a1b2"), "0xa1b2")
        compare(H.address("0xa1b2"), "0xa1b2")
    }
    function test_records_apps_mru_and_names() {
        const r = records()
        compare(r.map(x => x.id), [1, 2, 3, -98])                        // normal by id, then special
        compare(r[0].windows, 3)
        compare(r[0].apps, ["kitty", "firefox"])                          // distinct, focus order first
        compare(r[0].label, "1")
        compare(r[0].name, "")                                            // a name equal to the id is none
        compare(r[1].label, "web")
        verify(r[0].active && r[0].focused)
        verify(!r[1].active)
        verify(r[3].special)
        compare(records([], { 3: "a very long workspace name" })[2].label.length, 12)
        compare(records([], { 3: "a very long workspace name" })[2].label.slice(-1), "…")
    }
    function test_hyprland_data_taken_as_it_comes() {
        // a placeholder with an id already listed is dropped, a monitor listed twice counts once
        const ws = [{ id: 1, name: "1", monitor: "eDP-1" }, { id: 1, name: "1", monitor: "" },
                    { id: -1337, name: "mail", monitor: "eDP-1" }, { id: -98, name: "special:scratch", monitor: "eDP-1" }]
        const r = H.workspaceRecords(ws, [], [{ name: "eDP-1", activeWorkspace: 1 }], "eDP-1", [], [], {}, 12)
        compare(r.map(x => x.id), [-1337, 1, -98])
        compare(r[1].monitor, "eDP-1")
        verify(!r[0].special)                                             // a named workspace, not a special one
        compare(r[0].label, "mail")
        verify(r[2].special)
        compare(H.fixedIds(["DP-3", "DP-3", "eDP-1"], "DP-3"), [1, 2, 3, 4, 5])
    }
    function test_used_and_fixed_strips() {
        const r = records()
        compare(H.stripFor(r, "eDP-1", "used", ["eDP-1"], {}).pills.map(p => p.id), [1, 2])   // 3 is empty
        const f = H.stripFor(r, "eDP-1", "fixed", ["eDP-1"], {}).pills
        compare(f.length, 10)
        compare(f[4].windows, 0)                                          // empty fixed pills show
        compare(f[1].label, "web")
    }
    function test_scratch_pill() {
        const r = records()
        const s = H.stripFor(r, "eDP-1", "used", ["eDP-1"], { "eDP-1": "special:scratch" }).scratch
        compare(s.windows, 1)
        verify(s.shown)
        verify(!H.stripFor(r, "eDP-1", "used", ["eDP-1"], {}).scratch.shown)
    }
    function test_wheel_neighbour() {
        const strip = H.stripFor(records(), "eDP-1", "fixed", ["eDP-1"], {})
        compare(H.neighbour(strip, 1, 1), 2)                              // the next used one
        compare(H.neighbour(strip, 2, 1), 2)                              // none further: stay
        compare(H.neighbour(strip, 2, -1), 1)
    }
    function test_title_event_patch() {
        const e = H.parseTitleEvent("a1b2,vim: a, b, c")
        compare(e.address, "0xa1b2")
        compare(e.title, "vim: a, b, c")                                  // commas stay in the title
        const ws = [win("0xa1b2", "kitty", 1, 0), win("0xff", "zen", 1, 1)]
        const out = H.patchTitle(ws, "0xa1b2", "new")
        compare(out[0].title, "new")
        compare(ws[0].title, "kitty")                                     // the input is not changed
        verify(out[1] === ws[1])                                          // the other records are kept
        compare(H.patchTitle(ws, "0x0", "x"), null)                       // unknown: refresh instead
    }
    function test_urgent_records() {
        const r = records(["0xd"])
        verify(r[1].urgent)
        verify(!r[0].urgent)
        compare(H.bumpFocus(["0xa", "0xb"], "0xb"), ["0xb", "0xa"])
    }
    function test_split_event() {
        compare(H.splitEvent("1,special:scratch,eDP-1", 3), ["1", "special:scratch", "eDP-1"])
        compare(H.splitEvent("kbd,German (Neo, 2)", 2), ["kbd", "German (Neo, 2)"])
        compare(H.splitEvent("1", 2), ["1", ""])
    }

    // An invariant of hypr refuses the call (any other exception is not a refusal).
    function refuses(f) {
        try { f() } catch (e) { return String(e.message).indexOf("hypr invariant:") === 0 }
        return false
    }
    function accepts(f) {
        try { f() } catch (e) { return false }
        return true
    }

    function test_invariants_reject_broken_state() {
        verify(refuses(() => H.fixedIds(null, "eDP-1")))
        const ws = [{ id: 1, name: "1", monitor: "eDP-1" }]
        const mons = [{ name: "eDP-1", activeWorkspace: 1 }]
        verify(refuses(() => H.workspaceRecords(ws, [], mons, "eDP-1", [], [], {}, 1)))
        verify(refuses(() => H.workspaceRecords(ws, [], mons, "eDP-1", ["0xa", "0xa"], [], {}, 12)))
        verify(refuses(() => H.labelOf(1, "web", 0)))
        verify(refuses(() => H.stripFor([], "eDP-1", "all", ["eDP-1"], {})))
        verify(refuses(() => H.neighbour({ pills: [], scratch: null }, 1, 0)))
        // focus order: real addresses only (an empty activewindowv2 is no window), each once
        verify(refuses(() => H.bumpFocus(["0xa"], "0x")))
        verify(refuses(() => H.bumpFocus(["0xa"], "")))
        verify(refuses(() => H.bumpFocus(["0xa", "0xa"], "0xb")))
        verify(refuses(() => H.patchTitle([], "a1b2", "x")))
        verify(refuses(() => H.parseTitleEvent(null)))
        verify(refuses(() => H.splitEvent("a,b", 0)))
        verify(refuses(() => H.splitEvent(undefined, 2)))
        // a strip: pills once each, in id order, one active at most, no special workspace
        const p = (id, active, special) => ({ id: id, active: !!active, special: !!special })
        verify(accepts(() => H.checkStrip({ pills: [p(1, true), p(3)], scratch: null })))
        verify(refuses(() => H.checkStrip({ pills: [p(3), p(1)], scratch: null })))
        verify(refuses(() => H.checkStrip({ pills: [p(1), p(1)], scratch: null })))
        verify(refuses(() => H.checkStrip({ pills: [p(1, true), p(2, true)], scratch: null })))
        verify(refuses(() => H.checkStrip({ pills: [p(-98, false, true)], scratch: null })))
    }
}
