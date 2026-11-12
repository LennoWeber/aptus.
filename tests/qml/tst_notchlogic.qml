// The notch's presenter logic (surfaces/notch/js/notch.js, notch.md §2–§10).
import QtQuick
import QtTest
import "../../shell/surfaces/notch/js/notch.js" as T

TestCase {
    name: "notchlogic"

    // Tokens.surfaces as theme/tokens.json has them (the sizes notch.md §5–§8 names).
    readonly property var tokens: ({ toast: { width: 420, heights: [72, 104, 132] }, osd: { width: 300, height: 44 },
                                     event: { minWidth: 260, maxWidth: 360, height: 36 },
                                     card: { width: 420, padding: 12, pagerDotSize: 6 } })
    function state(notch, top) { return { notch: notch, passiveTop: top || { kind: "rest", entry: null } } }

    function test_view_of_states() {
        compare(T.viewOf(state("rest")).kind, "rest")
        const m = T.viewOf(state("spotlight", { kind: "osd", entry: { id: 1, payload: {} } }))
        compare(m.kind, "mode")                                          // an interactive mode wins
        compare(m.key, "mode:spotlight")
        const o = T.viewOf(state("rest", { kind: "osd", entry: { id: 3, payload: {} } }))
        compare(o.kind, "osd")
        compare(o.key, "osd")
        compare(T.viewOf(state("rest", { kind: "toast", entry: { id: 5, key: "n:12", payload: {} } })).key, "toast:n:12")
        const r = T.viewOf(state("rest", { kind: "toast", entry: { id: 5, key: "n:12", payload: { card: "colour" } } }))
        compare(r.kind, "result")                                        // a toast with a card is a result card
        compare(r.key, "result:n:12")
        compare(T.viewOf(state("rest", { kind: "event", entry: { id: 7, key: "", payload: {} } })).key, "event:#7")
        const c = T.viewOf(state("card:media", { kind: "card", entry: "media" }))
        compare(c.kind, "card")
        compare(c.activity, "media")
        compare(T.viewOf(state("rest", { kind: "hidden", entry: null })).kind, "hidden")
        compare(T.viewOf(state("keysPeek")).mode, "keysPeek")      // the passive peek
        compare(T.viewOf(state("keysPeek", { kind: "osd", entry: { id: 2, payload: {} } })).kind, "osd")
    }
    function test_layers_crossfade_and_in_place() {
        const osd = T.viewOf(state("rest", { kind: "osd", entry: { id: 1, payload: {} } }))
        let s = T.nextLayers([], osd, 0)
        compare(s.layers.length, 1)
        compare(s.serial, 1)
        verify(!s.layers[0].leaving)
        // another OSD (a new entry) is the same layer, updated in place
        s = T.nextLayers(s.layers, T.viewOf(state("rest", { kind: "osd", entry: { id: 4, payload: {} } })), s.serial)
        compare(s.layers.length, 1)
        compare(s.layers[0].uid, 1)
        compare(s.layers[0].entryId, 4)
        compare(s.serial, 1)
        // a toast crossfades: the OSD leaves, the toast enters
        s = T.nextLayers(s.layers, T.viewOf(state("rest", { kind: "toast", entry: { id: 5, key: "n:1", payload: {} } })), s.serial)
        compare(s.layers.map(l => l.leaving), [true, false])
        compare(s.layers[1].uid, 2)
        compare(s.layers[1].kind, "toast")
        // rest: everything leaves
        s = T.nextLayers(s.layers, T.viewOf(state("rest")), s.serial)
        verify(s.layers.every(l => l.leaving))
        compare(T.dropLayer(s.layers, 1).map(l => l.uid), [2])
    }
    function test_slots_priority_and_width() {
        const cands = [{ id: "media", slot: "right", priority: 1, width: 80 }, { id: "timer", slot: "left", priority: 3, width: 60 },
                       { id: "recording", slot: "left", priority: 5, width: 50 }]
        const a = T.assignSlots(cands, 50, 8, 400)
        compare(a.left, "recording")
        compare(a.right, "media")
        compare(a.waiting, ["timer"])
        // too wide: the lower-priority slot gives way
        const b = T.assignSlots(cands, 50, 8, 150)
        compare(b.left, "recording")
        compare(b.right, "")
        compare(b.waiting, ["media", "timer"])
        compare(T.assignSlots([], 50, 8, 400), { left: "", right: "", waiting: [] })
    }
    function test_toast_heights() {
        const h = [72, 104, 132]
        compare(T.toastHeight({}, h), 72)
        compare(T.toastHeight({ image: "file:///x.png" }, h), 72)
        compare(T.toastHeight({ actions: [{ id: "a", text: "A" }] }, h), 104)
        compare(T.toastHeight({ actions: [], reply: true }, h), 104)
        compare(T.toastHeight({ actions: [{ id: "a", text: "A" }], image: "file:///x.png" }, h), 132)
    }
    function test_bulge_sizes() {
        compare(T.bulgeSize("toast", { actions: [{ id: "a" }] }, null, tokens), { width: 420, height: 104 })
        compare(T.bulgeSize("osd", null, null, tokens), { width: 300, height: 44 })
        compare(T.bulgeSize("event", null, { width: 100 }, tokens), { width: 260, height: 36 })
        compare(T.bulgeSize("event", null, { width: 300 }, tokens), { width: 300, height: 36 })
        compare(T.bulgeSize("event", null, { width: 500 }, tokens), { width: 360, height: 36 })
        compare(T.bulgeSize("card", null, { height: 132, pager: false }, tokens), { width: 420, height: 132 })
        compare(T.bulgeSize("card", null, { height: 132, pager: true }, tokens), { width: 420, height: 150 })
        compare(T.bulgeSize("mode", null, { width: 600, height: 400 }, tokens), { width: 600, height: 400 })
        compare(T.bulgeSize("rest", null, null, tokens), { width: 0, height: 0 })
    }
    function test_due_entries() {
        const timing = { osdMs: 1500, eventMs: 1600, pinnedMs: 5000 }
        const passive = [{ id: 1, kind: "osd", born: 1000 }, { id: 2, kind: "event", born: 500 }, { id: 3, kind: "toast", born: 0 }]
        compare(T.dueEntries(passive, 2, 1200, 0, 2000, timing), { due: [], card: false, next: 2500 })
        compare(T.dueEntries(passive, 2, 1200, 0, 2600, timing), { due: [1], card: false, next: 2800 })
        compare(T.dueEntries(passive, 2, 1200, 0, 3000, timing), { due: [1, 2], card: false, next: 0 })
        // an event that is not on screen does not run out (rules.js drops it by age)
        compare(T.dueEntries(passive, 0, 0, 0, 9000, timing).due, [1])
        // the pinned card closes pinnedMs after the pointer left it
        compare(T.dueEntries([], 0, 0, 1000, 3000, timing), { due: [], card: false, next: 6000 })
        verify(T.dueEntries([], 0, 0, 1000, 6000, timing).card)
    }
    function test_countdown_pause_resume() {
        let c = T.countdownStart(5000, 0)
        verify(c.running)
        compare(T.countdownLeft(c, 1000), 4000)
        c = T.countdownPause(c, 4000)
        verify(!c.running)
        compare(T.countdownLeft(c, 9000), 1000)                          // paused: no time passes
        verify(T.countdownPause(c, 9500) === c)
        c = T.countdownResume(c, 9000, 2000)
        verify(c.running)
        compare(T.countdownLeft(c, 9500), 1500)                          // resumed with the minimum
        const none = T.countdownStart(0, 0)
        verify(!none.running)
        compare(T.countdownLeft(none, 1e9), Infinity)                    // a critical toast stays
        verify(T.countdownResume(none, 10, 2000) === none)
        // the entry stamp it counts for goes through pause and resume (wave-2 simplify A9)
        c = T.countdownStart(5000, 0, 3)
        compare(T.countdownResume(T.countdownPause(c, 10), 20, 0).rev, 3)
        compare(T.countdownStart(5000, 0).rev, 0)
    }
    function test_pager() {
        const ids = ["media", "timer", "focus"]
        compare(T.pagerStep(ids, "media", 1), "timer")
        compare(T.pagerStep(ids, "media", -1), "focus")
        compare(T.pagerStep(ids, "focus", 1), "media")
        compare(T.pagerStep(ids, "gone", 1), "media")
        compare(T.pagerStep([], "media", 1), "")
    }
    function test_long_date() {
        compare(T.longDate(new Date(2026, 10, 7)), "Saturday, 7 November · week 45")
        compare(T.longDate(new Date(2027, 0, 1)), "Friday, 1 January · week 53")
    }

    // An invariant of notch refuses the call (any other exception is not a refusal).
    function refuses(f) {
        try { f() } catch (e) { return String(e.message).indexOf("notch invariant:") === 0 }
        return false
    }
    function accepts(f) {
        try { f() } catch (e) { return false }
        return true
    }

    function test_invariants_reject_broken_state() {
        const osd = { uid: 1, kind: "osd", key: "osd", entryId: 1, activity: "", mode: "", leaving: false }
        const toast = { uid: 2, kind: "toast", key: "toast:n:1", entryId: 2, activity: "", mode: "", leaving: false }
        verify(refuses(() => T.viewOf({ notch: "bogus", passiveTop: null })))
        verify(refuses(() => T.viewOf({ notch: "rest", passiveTop: { kind: "weird", entry: null } })))
        verify(refuses(() => T.keyOf({ kind: "toast", entry: null })))
        // layers: never two current ones, a uid once, no rest layer, the serial ahead of every uid
        verify(accepts(() => T.checkLayers([osd, { uid: 2, kind: "toast", key: "toast:n:1", leaving: true }])))
        verify(refuses(() => T.checkLayers([osd, toast])))
        verify(refuses(() => T.checkLayers([osd, { uid: 1, kind: "toast", key: "toast:n:1", leaving: true }])))
        verify(refuses(() => T.checkLayers([{ uid: 3, kind: "rest", key: "x", leaving: false }])))
        verify(refuses(() => T.checkLayers([{ uid: 3, kind: "osd", key: "", leaving: false }])))
        verify(refuses(() => T.nextLayers([osd], { kind: "rest", key: "", entry: null, activity: "", mode: "" }, 0)))
        verify(refuses(() => T.dropLayer([osd], 1)))                       // only a leaving layer is dropped
        verify(!refuses(() => T.dropLayer([Object.assign({}, osd, { leaving: true })], 1)))
        // the layers after a view: one current layer for it, none at rest, the serial never back
        const rest = { kind: "rest", key: "", entry: null, activity: "", mode: "" }
        const osdView = { kind: "osd", key: "osd", entry: { id: 1 }, activity: "", mode: "" }
        verify(accepts(() => T.checkNext(osdView, 1, { layers: [osd], serial: 1 })))
        verify(refuses(() => T.checkNext(rest, 1, { layers: [osd], serial: 1 })))
        verify(refuses(() => T.checkNext(osdView, 1, { layers: [], serial: 1 })))
        verify(refuses(() => T.checkNext(osdView, 2, { layers: [osd], serial: 1 })))
        verify(refuses(() => T.checkNext(osdView, 1, { layers: [Object.assign({}, osd, { key: "toast:n:1", kind: "toast" })], serial: 1 })))
        // slots: known activities once each, a side, a width
        verify(refuses(() => T.assignSlots([{ id: "weather", slot: "left", priority: 1, width: 10 }], 50, 8, 400)))
        verify(refuses(() => T.assignSlots([{ id: "media", slot: "middle", priority: 1, width: 10 }], 50, 8, 400)))
        verify(refuses(() => T.assignSlots([{ id: "media", slot: "left", priority: 1, width: 10 },
                                            { id: "media", slot: "right", priority: 2, width: 10 }], 50, 8, 400)))
        verify(refuses(() => T.assignSlots([], 50, 8, 0)))
        const cands = [{ id: "media", slot: "right", priority: 1, width: 10 }, { id: "timer", slot: "left", priority: 2, width: 10 }]
        verify(accepts(() => T.checkSlots({ left: "timer", right: "media", waiting: [] }, cands)))
        verify(refuses(() => T.checkSlots({ left: "media", right: "media", waiting: [] }, cands)))
        verify(refuses(() => T.checkSlots({ left: "timer", right: "", waiting: [] }, cands)))     // media is lost
        verify(refuses(() => T.checkSlots({ left: "timer", right: "", waiting: ["timer"] }, cands)))  // and timer twice
        verify(refuses(() => T.checkSlots({ left: "media", right: "timer", waiting: [] }, cands)))     // the wrong sides
        verify(accepts(() => T.checkSlots({ left: "timer", right: "", waiting: ["media"] }, cands)))
        // sizes
        verify(refuses(() => T.toastHeight({}, [72, 104])))
        verify(refuses(() => T.toastHeight({}, [104, 72, 132])))
        verify(refuses(() => T.bulgeSize("weird", null, null, {})))
        // timers: positive once there are entries; ids once
        const timing = { osdMs: 1500, eventMs: 1600, pinnedMs: 5000 }
        verify(refuses(() => T.dueEntries([{ id: 1, kind: "osd", born: 0 }], 0, 0, 0, 10, { osdMs: 0, eventMs: 1600, pinnedMs: 5000 })))
        verify(refuses(() => T.dueEntries([], 0, 0, 100, 10, { osdMs: 0, eventMs: 0, pinnedMs: 0 })))
        verify(refuses(() => T.dueEntries([{ id: 1, kind: "osd", born: 0 }, { id: 1, kind: "toast", born: 0 }], 0, 0, 0, 10, timing)))
        verify(refuses(() => T.dueEntries([{ id: 1, kind: "card", born: 0 }], 0, 0, 0, 10, timing)))
        // countdowns
        verify(refuses(() => T.countdownStart(-1, 0)))
        verify(refuses(() => T.countdownLeft({ total: 0, remaining: 0, running: true, since: 0 }, 10)))
        verify(refuses(() => T.countdownPause({ total: 4000, remaining: NaN, running: true, since: 0 }, 10)))
        verify(refuses(() => T.countdownResume({ total: 4000, remaining: 10, running: false, since: 0 }, 10, -1)))
        verify(accepts(() => T.checkCountdown({ total: 4000, remaining: -20, running: false, since: 0 })))   // paused just after it ran out
        // pager and date
        verify(refuses(() => T.pagerStep(["media", "media"], "media", 1)))
        verify(refuses(() => T.pagerStep(["media", "timer"], "media", 2)))
        verify(refuses(() => T.longDate(new Date(NaN))))
        verify(refuses(() => T.longDate("2026-11-07")))
    }
}
