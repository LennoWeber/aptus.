// Tokens.qml itself (08 §3, M-30): the resolution from the real tokens.json and settings, and the
// theme crossfade. Runs against the mock import dir (tests/qml/mkmock.py).
import QtQuick
import QtTest
import qs.core

TestCase {
    name: "tokens"

    function init() {
        compare(Config.reset("appearance.mode"), "");
        tryCompare(Tokens, "_t", 1, 2000);
    }

    function test_resolved_at_start() {
        compare(Tokens.mode, "dark");
        verify(Tokens.ground.valid && Tokens.inkMain.valid);
        verify(Tokens.ground !== Tokens.inkMain);
    }

    function test_mode_change_crossfades() {
        const dark = String(Tokens.ground);      // a copy: a colour read from a property stays live
        compare(Config.set("appearance.mode", "light"), "");
        compare(Tokens.mode, "light");
        verify(Tokens._t < 1, "the colours fade, they do not jump");
        tryCompare(Tokens, "_t", 1, 2000);
        verify(String(Tokens.ground) !== dark);
    }

    function test_same_resolution_starts_no_crossfade() {
        const before = String(Tokens.ground);
        Tokens.resolveNow();
        compare(Tokens._t, 1);
        compare(String(Tokens.ground), before);
    }
}
