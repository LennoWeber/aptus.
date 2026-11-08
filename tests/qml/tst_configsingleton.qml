// The Config singleton itself (07 §8, settings.md §4; tst_config covers core/js/config.js):
// defaults from the real schema, set/reset and the cross-key rules. Runs against the mock import
// dir (tests/qml/mkmock.py), whose FileView reads the schema and keeps every write in memory; the
// settings file does not exist, so the defaults apply.
import QtQuick
import QtTest
import qs.core

TestCase {
    name: "configsingleton"

    SignalSpy { id: invalid; target: Config; signalName: "settingInvalid" }

    function init() {
        compare(Config.resetPage("focus"), "");
        compare(Config.resetPage("power"), "");
        invalid.clear();
    }

    function test_defaults_loaded() {
        verify(Config.loaded);
        compare(Config.get("focus.default"), 50);
        compare(Config.get("focus.durations"), [25, 50, 90]);
        compare(Config.get("idle.lockAfter"), 300);
    }

    function test_set_refuses_a_cross_rule() {
        verify(Config.set("focus.default", 60) !== "", "60 is not one of the durations");
        compare(Config.get("focus.default"), 50);
        compare(invalid.count, 1);
    }

    function test_reset_refuses_a_cross_rule() {
        compare(Config.set("focus.durations", [50, 60, 120]), "");
        compare(Config.set("focus.default", 60), "");
        compare(Config.set("focus.durations", [30, 60, 120]), "");
        // the default durations [25, 50, 90] do not hold 60: refused, nothing changes
        verify(Config.reset("focus.durations") !== "");
        compare(Config.get("focus.durations"), [30, 60, 120]);
        compare(invalid.count, 1);
        // the whole page goes back together and is valid
        compare(Config.resetPage("focus"), "");
        compare(Config.get("focus.durations"), [25, 50, 90]);
        compare(Config.get("focus.default"), 50);
    }

    function test_reset_refuses_an_order_rule() {
        compare(Config.set("idle.screenOffAfter", 1200), "");
        compare(Config.set("idle.lockAfter", 900), "");
        compare(Config.set("idle.dimAfter", 600), "");
        // lockAfter back to 300 would put it before dimAfter 600
        verify(Config.reset("idle.lockAfter") !== "");
        compare(Config.get("idle.lockAfter"), 900);
        compare(Config.reset("idle.dimAfter"), "");
        compare(Config.reset("idle.lockAfter"), "");
        compare(Config.get("idle.lockAfter"), 300);
    }

    function test_reset_unknown_key() {
        compare(Config.reset("no.such.key"), "unknown setting");
    }
}
