// Tokens.qml itself (08 §3, M-30): the resolution from the real tokens.json and settings, and the
// theme crossfade. Runs against the mock import dir (tests/qml/mkmock.py).
import QtQuick
import QtTest
import qs.core

TestCase {
    name: "tokens"

    function init() {
        // the mock FileView loads tokens.json after the turn, so the first resolution comes later
        tryVerify(() => Tokens._r !== null);
        compare(Config.reset("appearance.mode"), "");
        tryCompare(Tokens, "mode", "dark");                  // resolved after the turn (coalesced)
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
        tryCompare(Tokens, "mode", "light");
        verify(Tokens._t < 1, "the colours fade, they do not jump");
        tryCompare(Tokens, "_t", 1, 2000);
        verify(String(Tokens.ground) !== dark);
    }

    // Wave-2 simplify A5: `resolved` comes for the shell's own change of the apps' paint only.
    SignalSpy { id: resolvedSpy; target: Tokens; signalName: "resolved" }
    function test_resolved_only_for_a_change_of_paint() {
        resolvedSpy.clear();
        Tokens.resolveNow();                                  // nothing changed
        compare(resolvedSpy.count, 0);
        compare(Config.set("appearance.mode", "light"), "");
        tryCompare(Tokens, "mode", "light");
        compare(resolvedSpy.count, 1);
        // an outside resolution (resolved.json) changes the paint without it
        Tokens._resolvedSeen = true;
        const outside = JSON.parse(JSON.stringify(Tokens._r));
        outside.accentName = outside.accentName === "jade" ? "sky" : "jade";
        Tokens._external(JSON.stringify(outside));
        compare(Tokens.accentName, outside.accentName);
        compare(resolvedSpy.count, 1);
    }

    function test_same_resolution_starts_no_crossfade() {
        const before = String(Tokens.ground);
        Tokens.resolveNow();
        compare(Tokens._t, 1);
        compare(String(Tokens.ground), before);
    }
}
