// SurfaceManager transition rules (07 §5, 05 §2–§3).
import QtQuick
import QtTest
import "../../shell/core/js/rules.js" as Lib

TestCase {
    name: "rules"

    function test_open_notch_mode() { fail("not implemented"); }

    function test_morph_between_modes() { fail("not implemented"); }

    function test_mode_closes_deck() { fail("not implemented"); }

    function test_deck_closes_mode() { fail("not implemented"); }

    function test_overview_closes_all() { fail("not implemented"); }

    function test_locked_refuses() { fail("not implemented"); }

    function test_locked_allows_osd() { fail("not implemented"); }

    function test_polkit_queues() { fail("not implemented"); }

    function test_polkit_close_flushes_queue() { fail("not implemented"); }

    function test_toast_queued_behind_mode() { fail("not implemented"); }

    function test_old_toast_dropped() { fail("not implemented"); }

    function test_osd_beats_toast() { fail("not implemented"); }

    function test_event_expires() { fail("not implemented"); }

    function test_monitor_removed_instant() { fail("not implemented"); }

    function test_active_monitor_change_closes_mode() { fail("not implemented"); }

    function test_back_ladder_menu_first() { fail("not implemented"); }

    function test_back_handler_steps() { fail("not implemented"); }

    function test_back_closes() { fail("not implemented"); }

    function test_toggle() { fail("not implemented"); }

    function test_interactive_and_top() { fail("not implemented"); }

    function test_settings_toggle() { fail("not implemented"); }

    function test_inputs_not_mutated() { fail("not implemented"); }

    function test_keys_peek_not_interactive() { fail("not implemented"); }

    function test_hover_card_not_interactive() { fail("not implemented"); }

    function test_pinned_card_takes_keyboard() { fail("not implemented"); }

    function test_pinned_card_yields_to_toast() { fail("not implemented"); }

    function test_osd_suppressed_under_mode() { fail("not implemented"); }

    function test_fullscreen_hides_except_allowed() { fail("not implemented"); }

    function test_post_key_replaces() { fail("not implemented"); }

    function test_update_payload() { fail("not implemented"); }

    function test_deck_page_push_pop() { fail("not implemented"); }

    function test_toggle_returns_state() { fail("not implemented"); }

    function test_previous_window_recorded() { fail("not implemented"); }

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
            try { Lib.checkState(monitors, global) } catch (e) { thrown = String(e) }
            verify(thrown.indexOf("rules invariant") >= 0, why + ": " + thrown)
        }
        Lib.checkState({ A: mon("A", {}) }, glob({}))
        bad({ A: mon("B", {}) }, glob({}), "key ≠ name")
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
    function test_last_polkit_monitor_removed_drops_queue() { fail("not implemented"); }
}
