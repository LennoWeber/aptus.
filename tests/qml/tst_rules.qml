// Surface transition rules (07 §5, 05 §2/§3, notch.md §9).
import QtQuick
import QtTest
import "../../shell/core/js/rules.js" as R

TestCase {
    name: "rules"

    // A state with monitors A (active) and B.
    function fresh() {
        var r = R.addMonitor({}, R.newGlobal(), "A", 0)
        return R.addMonitor(r.monitors, r.global, "B", 0)
    }
    function op(r, fn, req, now) { return R[fn](r.monitors, r.global, req, now || 1000) }
    function o(r, surface, args, monitor, now) { return op(r, "open", { surface: surface, args: args, monitor: monitor }, now) }
    function c(r, surface, monitor, now) { return op(r, "close", { surface: surface, monitor: monitor }, now) }
    function t(r, surface, args, now) { return op(r, "toggle", { surface: surface, args: args }, now) }
    function p(r, kind, payload, prio, now, key, monitor) { return R.post(r.monitors, r.global, kind, payload || {}, prio || 0, monitor || "", key || "", now || 1000) }
    function kinds(r) { return r.effects.map(function (e) { return e.kind + ":" + e.surface }).join(" ") }

    function test_open_notch_mode() {
        var r = o(fresh(), "spotlight", { scope: "apps" })
        compare(r.monitors.A.notch, "spotlight")
        compare(r.monitors.A.notchArgs.scope, "apps")
        compare(r.monitors.A.notchSerial, 1)
        compare(r.monitors.B.notch, "rest")
        compare(kinds(r), "opened:spotlight")
    }
    function test_morph_between_modes() {
        var r = o(o(fresh(), "spotlight"), "today")
        compare(r.monitors.A.notch, "today")
        compare(r.monitors.A.hero, "today")
        compare(kinds(r), "closed:spotlight opened:today")
    }
    function test_mode_closes_deck() {
        var r = o(o(fresh(), "deck"), "spotlight")
        verify(!r.monitors.A.deck)
        compare(r.monitors.A.notch, "spotlight")
        compare(kinds(r), "closed:deck opened:spotlight")
    }
    function test_deck_closes_mode() {
        var r = o(o(fresh(), "today"), "deck")
        compare(r.monitors.A.notch, "rest")
        verify(r.monitors.A.deck)
        compare(r.monitors.A.hero, "deck")
    }
    function test_overview_closes_all() {
        var r = o(fresh(), "deck")
        r = R.openMenu(r.monitors, r.global, "A", { model: [] }, 1)
        r = o(r, "overview")
        verify(!r.monitors.A.deck); compare(r.monitors.A.menu, null)
        verify(r.monitors.A.overview)
        r = o(r, "spotlight")
        verify(!r.monitors.A.overview)
    }
    function test_locked_refuses() {
        var r = fresh()
        r = R.setLocked(r.monitors, r.global, true, 1)
        r = o(r, "spotlight")
        compare(r.monitors.A.notch, "rest"); compare(kinds(r), "refused:spotlight")
        compare(kinds(t(r, "settings")), "refused:settings")
        compare(kinds(p(r, "toast", {})), "refused:toast")
    }
    function test_locked_allows_osd() {
        var r = fresh()
        r = R.setLocked(r.monitors, r.global, true, 1)
        r = p(r, "osd", { kind: "volume", value: 40 }, 0, 1000, "volume")
        compare(r.monitors.A.passiveTop.kind, "osd")
    }
    function test_polkit_queues() {
        var r = o(fresh(), "polkit", { id: 7 })
        compare(r.global.polkitMonitor, "A")
        r = o(r, "spotlight", {}, "B")
        compare(kinds(r), "queued:spotlight")
        compare(r.monitors.B.notch, "rest")
        compare(r.global.pending.length, 1)
    }
    function test_polkit_close_flushes_queue() {
        var r = o(fresh(), "polkit")
        r = o(r, "spotlight", { q: "x" }, "B")
        r = t(r, "deck")
        r = c(r, "polkit")
        compare(r.global.polkitMonitor, "")
        compare(r.monitors.A.notch, "rest")
        compare(r.monitors.B.notch, "spotlight")
        compare(r.monitors.B.notchArgs.q, "x")
        verify(r.monitors.A.deck)
        compare(r.global.pending.length, 0)
    }
    function test_toast_queued_behind_mode() {
        var r = o(fresh(), "spotlight", {}, "", 1000)
        r = p(r, "toast", { title: "Hi" }, 1, 2000)
        compare(r.monitors.A.passiveTop.kind, "rest")
        compare(r.monitors.A.passive.length, 1)
        verify(r.monitors.A.passive[0].waited)
        r = c(r, "spotlight", "", 10000)
        compare(r.monitors.A.passiveTop.kind, "toast")
        verify(!r.monitors.A.passive[0].waited)
    }
    function test_old_toast_dropped() {
        var r = o(fresh(), "spotlight", {}, "", 1000)
        r = p(r, "toast", {}, 1, 2000)
        r = c(r, "spotlight", "", 2000 + 30001)
        compare(r.monitors.A.passive.length, 0)
        compare(r.monitors.A.passiveTop.kind, "rest")
        // a shown toast is never dropped for its age (critical toasts have no timeout)
        r = p(r, "toast", {}, 2, 100000)
        r = R.tick(r.monitors, r.global, 900000)
        compare(r.monitors.A.passiveTop.kind, "toast")
    }
    function test_osd_beats_toast() {
        var r = p(fresh(), "toast", { n: 1 }, 1, 1000)
        r = p(r, "osd", { kind: "volume", value: 10 }, 0, 1100, "volume")
        compare(r.monitors.A.passiveTop.kind, "osd")
        r = R.dismiss(r.monitors, r.global, "A", r.id, 2300)
        compare(r.monitors.A.passiveTop.kind, "toast")
        compare(r.monitors.A.passiveTop.entry.payload.n, 1)
    }
    function test_event_expires() {
        var r = p(fresh(), "toast", {}, 1, 1000)
        r = p(r, "event", { text: "Copied" }, 0, 1000)
        compare(r.monitors.A.passiveTop.kind, "toast")
        r = R.tick(r.monitors, r.global, 1000 + 4001)
        compare(r.monitors.A.passive.length, 1)
        compare(r.monitors.A.passive[0].kind, "toast")
        // the event being shown is not cut off
        r = p(fresh(), "event", { text: "Dark" }, 0, 1000)
        r = R.tick(r.monitors, r.global, 6000)
        compare(r.monitors.A.passiveTop.kind, "event")
        // events dropped under an interactive mode
        r = o(fresh(), "today")
        compare(kinds(p(r, "event", {})), "refused:event")
    }
    function test_monitor_removed_instant() {
        var r = o(fresh(), "polkit", { id: 3 }, "B")
        r = o(r, "deck", {}, "B")              // queued behind polkit
        r = R.removeMonitor(r.monitors, r.global, "B", 1)
        verify(!("B" in r.monitors))
        compare(r.global.polkitMonitor, "A")
        compare(r.monitors.A.notch, "polkit")
        compare(r.monitors.A.notchArgs.id, 3)
        verify(r.monitors.A.instant)
        verify(kinds(r).indexOf("closed:polkit") === 0)
        r = R.removeMonitor(r.monitors, r.global, "A", 1)
        compare(r.global.activeMonitor, "")
    }
    function test_active_monitor_change_closes_mode() {
        var r = o(fresh(), "spotlight")
        r = p(r, "toast", {}, 1, 1000, "", "A")
        r = R.setActive(r.monitors, r.global, "B", 1000)
        compare(r.monitors.A.notch, "rest")
        compare(r.monitors.A.passiveTop.kind, "toast")
        compare(r.global.activeMonitor, "B")
        r = o(r, "polkit")
        r = R.setActive(r.monitors, r.global, "A", 1000)
        compare(r.monitors.B.notch, "polkit")       // polkit stays
    }
    function test_back_ladder_menu_first() {
        var r = o(fresh(), "spotlight")
        r = R.openMenu(r.monitors, r.global, "A", { model: [] }, 1)
        compare(r.monitors.A.top, "menu")
        r = R.back(r.monitors, r.global, "A", false, 1)
        compare(r.monitors.A.menu, null)
        compare(r.monitors.A.notch, "spotlight")
    }
    function test_back_handler_steps() {
        var r = o(fresh(), "today", { day: "2026-11-07" })
        r = R.back(r.monitors, r.global, "A", true, 1)
        compare(r.monitors.A.notch, "today")
        compare(r.effects.length, 0)
    }
    function test_back_closes() {
        var r = o(fresh(), "today")
        r = R.back(r.monitors, r.global, "A", false, 1)
        compare(r.monitors.A.notch, "rest")
        r = o(r, "capture", { mode: "region" })
        r = R.back(r.monitors, r.global, "A", false, 1)
        compare(r.monitors.A.capture, null); compare(r.monitors.B.capture, null)
        r = R.back(r.monitors, r.global, "A", false, 1)   // nothing open: no-op
        compare(r.effects.length, 0)
    }
    function test_toggle() {
        var r = t(fresh(), "deck")
        verify(r.monitors.A.deck)
        r = t(r, "deck")
        verify(!r.monitors.A.deck)
        r = t(t(r, "spotlight"), "today")
        compare(r.monitors.A.notch, "today")
    }
    function test_interactive_and_top() {
        var r = fresh()
        verify(!r.monitors.A.interactive); compare(r.monitors.A.top, "")
        r = o(r, "deck", { page: "wifi" })
        verify(r.monitors.A.interactive); verify(r.monitors.A.keyboard); compare(r.monitors.A.top, "deck")
        r = o(r, "capture")
        compare(r.monitors.A.top, "capture"); verify(r.monitors.B.interactive)
    }
    function test_settings_toggle() {
        var r = t(fresh(), "settings")
        verify(r.global.settingsOpen); compare(kinds(r), "opened:settings")
        r = t(r, "settings")
        compare(kinds(r), "settingsFocus:settings"); verify(r.global.settingsOpen)
        r = R.setSettingsFocused(r.monitors, r.global, true, 1)
        r = t(r, "settings")
        verify(!r.global.settingsOpen); verify(!r.global.settingsFocused)
        r = o(o(r, "settings", { page: "keys" }), "settings", { page: "about" })
        compare(r.global.settingsArgs.page, "about")
    }
    function test_inputs_not_mutated() {
        var r = p(fresh(), "toast", { n: 1 }, 1, 1000)
        var snap = JSON.stringify(r)
        var r2 = o(r, "spotlight")
        r2 = p(r2, "toast", { n: 2 }, 1, 1200)
        r2 = R.back(r2.monitors, r2.global, "A", false, 1300)
        r2 = R.removeMonitor(r2.monitors, r2.global, "B", 1400)
        compare(JSON.stringify(r), snap)
    }
    function test_keys_peek_not_interactive() {
        var r = o(fresh(), "keysPeek")
        compare(r.monitors.A.notch, "keysPeek")
        verify(!r.monitors.A.interactive); verify(!r.monitors.A.keyboard); compare(r.monitors.A.top, "")
        r = p(r, "toast", {}, 1, 1000)
        compare(r.monitors.A.passiveTop.kind, "toast")   // toasts are not queued behind the peek
        compare(kinds(o(o(fresh(), "today"), "keysPeek")), "refused:keysPeek")
    }
    function test_hover_card_not_interactive() {
        var r = o(fresh(), "card:media")
        verify(!r.monitors.A.interactive); verify(!r.monitors.A.keyboard)
        compare(r.monitors.A.passiveTop.kind, "card"); compare(r.monitors.A.passiveTop.entry, "media")
        r = o(r, "deck")                                // a hover card stays with the Deck
        compare(r.monitors.A.notch, "card:media")
        verify(!R.isNotchMode("card:nonsense"))
    }
    function test_pinned_card_takes_keyboard() {
        var r = o(o(fresh(), "deck"), "card:timer", { pinned: true })
        verify(!r.monitors.A.deck)
        verify(!r.monitors.A.interactive); verify(r.monitors.A.keyboard)
        compare(r.monitors.A.top, "card:timer")
        r = R.back(r.monitors, r.global, "A", false, 1)
        compare(r.monitors.A.notch, "rest")
    }
    function test_pinned_card_yields_to_toast() {
        var r = o(fresh(), "card:focus", { pinned: true })
        r = p(r, "toast", {}, 1, 1000)
        compare(r.monitors.A.passiveTop.kind, "toast")
        compare(r.monitors.A.notch, "card:focus")
        r = R.dismiss(r.monitors, r.global, "A", r.id, 2000)
        compare(r.monitors.A.passiveTop.kind, "card")
    }
    function test_osd_suppressed_under_mode() {
        compare(kinds(p(o(fresh(), "spotlight"), "osd", {})), "refused:osd")
        // the Deck coexists with passive states (05 §2): OSD and toasts show while it is open
        compare(p(o(fresh(), "deck"), "osd", {}).monitors.A.passiveTop.kind, "osd")
        compare(p(o(fresh(), "deck"), "toast", {}).monitors.A.passiveTop.kind, "toast")
    }
    function test_fullscreen_hides_except_allowed() {
        var r = fresh()
        r = R.setFullscreen(r.monitors, r.global, "A", true, 1)
        r = p(r, "toast", {}, 1, 1000)
        compare(r.monitors.A.passiveTop.kind, "hidden")
        r = p(r, "toast", {}, 2, 1001)
        compare(r.monitors.A.passiveTop.kind, "toast"); compare(r.monitors.A.passiveTop.entry.priority, 2)
        r = p(r, "osd", {}, 0, 1002, "volume")
        compare(r.monitors.A.passiveTop.kind, "osd")
        var g = {}; for (var k in r.global) g[k] = r.global[k]
        g.overFullscreen = "none"
        compare(R.tick(r.monitors, g, 1003).monitors.A.passiveTop.kind, "osd")
        g.overFullscreen = "all"
        r = R.dismiss(r.monitors, g, "A", r.id, 1004)
        compare(r.monitors.A.passiveTop.kind, "toast"); compare(r.monitors.A.passiveTop.entry.priority, 2)
        compare(R.setFullscreen(r.monitors, r.global, "A", false, 1).monitors.A.fullscreen, false)
    }
    function test_post_key_replaces() {
        var r = p(fresh(), "osd", { value: 10 }, 0, 1000, "volume")
        var id = r.id
        r = p(r, "toast", {}, 1, 1000)
        r = p(r, "osd", { value: 20 }, 0, 1500, "volume")
        compare(r.id, id)
        compare(r.monitors.A.passive.length, 2)
        compare(r.monitors.A.passive[0].payload.value, 20)
        compare(r.monitors.A.passive[0].born, 1500)
        r = p(r, "osd", { value: 1 }, 0, 1600, "brightness")
        verify(r.id !== id)
    }
    function test_update_payload() {
        var r = p(fresh(), "toast", { count: 1 }, 1, 1000)
        var id = r.id
        r = R.update(r.monitors, r.global, "A", id, { count: 3 }, 1500)
        compare(r.monitors.A.passive[0].payload.count, 3)
        compare(r.monitors.A.passive[0].born, 1000)
        r = R.update(r.monitors, r.global, "", 999, {}, 1500)    // unknown id: no change
        compare(r.monitors.A.passive.length, 1)
    }
    function test_deck_page_push_pop() {
        var r = o(fresh(), "deck", { page: "wifi" })
        compare(r.monitors.A.deckPages, ["main", "wifi"])
        r = o(r, "deck", { page: "bluetooth" })
        compare(r.monitors.A.deckPages, ["main", "bluetooth"])
        r = R.back(r.monitors, r.global, "A", false, 1)
        compare(r.monitors.A.deckPages, ["main"]); verify(r.monitors.A.deck)
        r = R.back(r.monitors, r.global, "A", false, 1)
        verify(!r.monitors.A.deck)
    }
    function test_toggle_returns_state() {
        var r = t(fresh(), "today")
        verify(R.isOpen(r.monitors.A, r.global, "today"))
        r = t(r, "today")
        verify(!R.isOpen(r.monitors.A, r.global, "today"))
        r = o(r, "polkit")
        r = t(r, "today")
        compare(kinds(r), "queued:today")
        r = c(r, "polkit")
        verify(R.isOpen(r.monitors.A, r.global, "today"))
    }
    function test_previous_window_recorded() {
        var r = fresh()
        var g = {}; for (var k in r.global) g[k] = r.global[k]
        g.currentWindow = "0xabc"
        r = R.open(r.monitors, g, { surface: "spotlight" }, 1)
        compare(r.global.previousWindow, "0xabc")
        var g2 = {}; for (var k2 in r.global) g2[k2] = r.global[k2]
        g2.currentWindow = "0xdef"
        r = R.open(r.monitors, g2, { surface: "today" }, 2)          // still keyboard: unchanged
        compare(r.global.previousWindow, "0xabc")
    }

    // Invariants (phase 6): checkState rejects states no operation may produce.
    function test_invariants_reject_broken_state() {
        function mon(name, o) {
            var m = { name: name, notch: "rest", deckPages: ["main"], deck: false, overview: false,
                      menu: null, capture: null, passive: [] }
            for (var k in o) m[k] = o[k]
            return m
        }
        function glob(o) {
            var g = { locked: false, polkitMonitor: "", pending: [], settingsOpen: false,
                      settingsFocused: false, passiveSerial: 0 }
            for (var k in o) g[k] = o[k]
            return g
        }
        function bad(monitors, global, why) {
            var thrown = ""
            try { R.checkState(monitors, global) } catch (e) { thrown = String(e) }
            verify(thrown.indexOf("rules invariant") >= 0, why + ": " + thrown)
        }
        R.checkState({ A: mon("A", {}) }, glob({}))
        // states the spec allows must pass (an over-strict check would crash correct code)
        R.checkState({ A: mon("A", { deck: true, notch: "keysPeek" }) }, glob({}))
        R.checkState({ A: mon("A", { deck: true, notch: "card:media" }) }, glob({}))
        R.checkState({ A: mon("A", { capture: { args: {} } }), B: mon("B", { capture: { args: {} } }) }, glob({}))
        R.checkState({ A: mon("A", { capture: { args: { includeShell: true } }, deck: true, menu: {} }) }, glob({}))
        R.checkState({ A: mon("A", { notch: "polkit" }), B: mon("B", { deck: true }) },
                     glob({ polkitMonitor: "A", pending: [{ op: "open", surface: "spotlight", args: {}, monitor: "" }] }))
        R.checkState({ A: mon("A", { deck: true, deckPages: ["main", "wifi"] }) }, glob({ locked: true }))
        bad({ A: mon("B", {}) }, glob({}), "key ≠ name")
        bad({ A: mon("A", { notch: 3 }) }, glob({}), "a notch that is not a string")
        bad({ A: mon("A", { deckPages: ["wifi"] }) }, glob({}), "a Deck stack without main")
        bad({ A: mon("A", { overview: true, notch: "spotlight" }) }, glob({}), "overview + mode")
        bad({ A: mon("A", { capture: { args: {} }, menu: {} }) }, glob({}), "capture + menu")
        bad({ A: mon("A", { capture: { args: {} }, notch: "today" }) }, glob({}), "capture + mode")
        bad({ A: mon("A", { capture: { args: {} }, overview: true }) }, glob({}), "capture + overview")
        bad({ A: mon("A", { capture: { args: { includeShell: true } }, notch: "polkit" }) },
            glob({ polkitMonitor: "A" }), "capture + polkit")
        bad({ A: mon("A", { notch: "polkit" }), B: mon("B", { notch: "polkit" }) }, glob({ polkitMonitor: "A" }), "two polkit")
        bad({ A: mon("A", { notch: "polkit" }), B: mon("B", {}) }, glob({ polkitMonitor: "B" }), "wrong polkitMonitor")
        bad({ A: mon("A", { notch: "polkit" }) }, glob({ polkitMonitor: "A", pending: [{ op: "open", surface: "polkit" }] }), "polkit queued")
        bad({ A: mon("A", { notch: "polkit" }) }, glob({ polkitMonitor: "A", pending: [{ op: "open" }] }), "queued without surface")
        bad({ A: mon("A", { capture: { args: {} } }) }, glob({ locked: true }), "capture while locked")
        bad({ A: mon("A", { passive: [{ id: 1, kind: "banner" }] }) }, glob({ passiveSerial: 1 }), "unknown passive kind")
        bad({ A: mon("A", { passive: [{ id: 3, kind: "toast" }] }) }, glob({ passiveSerial: 2 }), "id beyond the serial")
        bad({ A: mon("A", { passive: [{ id: 1, kind: "osd", key: "vol" }, { id: 2, kind: "osd", key: "vol" }] }) },
            glob({ passiveSerial: 2 }), "key twice")
        bad({ A: mon("A", { notch: "nonsense" }) }, glob({}), "unknown notch")
        bad({ A: mon("A", { deck: true, notch: "spotlight" }) }, glob({}), "deck + mode")
        bad({ A: mon("A", { overview: true, deck: true }) }, glob({}), "overview + deck")
        bad({ A: mon("A", { capture: {} }), B: mon("B", {}) }, glob({}), "capture on one monitor")
        bad({ A: mon("A", { notch: "polkit" }) }, glob({}), "polkit without polkitMonitor")
        bad({ A: mon("A", {}) }, glob({ pending: [{ op: "open", surface: "deck" }] }), "queue without polkit")
        bad({ A: mon("A", { menu: {} }) }, glob({ locked: true }), "menu while locked")
        bad({ A: mon("A", { passive: [{ id: 1, kind: "toast" }, { id: 1, kind: "osd" }] }) }, glob({ passiveSerial: 2 }), "id twice")
        bad({ A: mon("A", {}) }, glob({ settingsFocused: true }), "focused but closed")
    }

    // The last monitor holding polkit goes away: the queue behind it is dropped (found by the
    // phase-6 invariants: nothing is left to replay it onto).
    function test_last_polkit_monitor_removed_drops_queue() {
        var r = o(fresh(), "polkit", { id: 4 }, "A")
        r = o(r, "deck", {}, "A")                              // queued behind polkit
        compare(r.global.pending.length, 1)
        r = R.removeMonitor(r.monitors, r.global, "B", 1)
        r = R.removeMonitor(r.monitors, r.global, "A", 1)     // the last one, holding polkit
        compare(r.global.polkitMonitor, "")
        compare(r.global.pending.length, 0)
        R.checkState(r.monitors, r.global)
    }

    // Arbitration decisions behind the invariants (07 §5, capture.md §7).
    function test_capture_closes_open_surfaces() {
        var r = o(o(o(fresh(), "deck", {}, "B"), "today", {}, "A"), "capture", { mode: "region" })
        compare(r.monitors.A.notch, "rest")
        verify(!r.monitors.B.deck)
        verify(r.monitors.A.capture !== null && r.monitors.B.capture !== null)
        var kept = o(o(fresh(), "deck", {}, "B"), "capture", { includeShell: true })
        verify(kept.monitors.B.deck, "includeShell keeps the Deck in the image")
        R.checkState(kept.monitors, kept.global)
    }
    function test_monitor_added_cancels_capture() {
        var r = o(fresh(), "capture", {})
        r = R.addMonitor(r.monitors, r.global, "C", 1000)
        verify(r.monitors.A.capture === null && r.monitors.C.capture === null)
        compare(kinds(r), "closed:capture")
        r = o(r, "capture", {})
        r = R.removeMonitor(r.monitors, r.global, "C", 1000)
        verify(r.monitors.A.capture !== null, "a removed monitor just drops out")
    }
    function test_lock_closes_menu_and_capture_only() {
        var r = o(fresh(), "deck", {}, "B")
        r = R.openMenu(r.monitors, r.global, "A", { id: "m" }, 1000)
        r = R.setLocked(r.monitors, r.global, true, 1000)
        verify(r.monitors.A.menu === null)
        verify(r.monitors.B.deck, "the Deck stays under the lock")
        r = o(R.setLocked(fresh().monitors, fresh().global, false, 1000), "capture", {})
        r = R.setLocked(r.monitors, r.global, true, 1000)
        verify(r.monitors.A.capture === null)
    }
    function test_polkit_closes_overview() {
        var r = o(o(fresh(), "overview"), "polkit", { id: 1 })
        verify(!r.monitors.A.overview)
        compare(r.monitors.A.notch, "polkit")
        compare(o(o(fresh(), "overview"), "keysPeek").monitors.A.notch, "rest")
    }

    function test_second_polkit_request_stays_on_its_monitor() {
        var r = o(fresh(), "polkit", { id: 1 }, "A")
        r = R.setActive(r.monitors, r.global, "B", 1000)
        r = o(r, "polkit", { id: 2 })
        compare(r.global.polkitMonitor, "A")
        compare(r.monitors.A.notchArgs.id, 2)
        compare(r.monitors.B.notch, "rest")
    }
    function test_polkit_monitor_removed_while_locked() {
        var r = o(o(fresh(), "polkit", { id: 1 }, "A"), "deck")
        compare(r.global.pending.length, 1)
        r = R.setLocked(r.monitors, r.global, true, 1000)
        r = R.removeMonitor(r.monitors, r.global, "A", 1000)
        compare(r.global.polkitMonitor, "")
        compare(r.global.pending.length, 0, "cancelled, nothing to replay onto")
    }
    function test_operations_default_now() {
        var r = fresh()
        r = R.post(r.monitors, r.global, "event", { text: "x" }, 0, "", "")
        verify(typeof r.monitors.A.passive[0].born === "number", "born is a time without `now`")
    }
}
