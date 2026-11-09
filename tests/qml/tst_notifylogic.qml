// The notification logic (services/js/notifications.js): the interruption policy of 05 §8, toast
// timing, stacks, held summaries, markup and the history (notch.md §6).
import QtQuick
import QtTest
import "../../shell/services/js/notifications.js" as N

TestCase {
    name: "notifylogic"

    function test_policy_table() { skip("phase 7") }
    function test_allowlist_overrides_dnd_and_focus() { skip("phase 7") }
    function test_muted_app_goes_to_today() { skip("phase 7") }
    function test_progress_hint() { skip("phase 7") }
    function test_timeout_formula() { skip("phase 7") }
    function test_timeout_setting() { skip("phase 7") }
    function test_stack_window() { skip("phase 7") }
    function test_held_summary() { skip("phase 7") }
    function test_markup_reduction() { skip("phase 7") }
    function test_history_order_trim_and_read() { skip("phase 7") }
    function test_persistence_round_trip() { skip("phase 7") }
    function test_fallback_app_and_glyph() { skip("phase 7") }
}
