// The active-player rule (services/js/media.js, notch.md §5, 05 §7).
import QtQuick
import QtTest
import "../../shell/services/js/media.js" as M

TestCase {
    name: "medialogic"

    function p(key, playing, since, last) { return { key: key, identity: key, desktopEntry: "", playing: playing, playingSince: since, lastActive: last } }

    function test_most_recent_playing_wins() {
        compare(M.pickActive([p("a", true, 10, 10), p("b", true, 20, 20)]), "b")
        compare(M.pickActive([p("a", true, 30, 30), p("b", true, 20, 20)]), "a")
        // a playing one always beats one that was active more recently but paused
        compare(M.pickActive([p("a", false, 0, 99), p("b", true, 5, 5)]), "b")
    }
    function test_none_playing_last_played() {
        compare(M.pickActive([p("a", false, 10, 50), p("b", false, 20, 40)]), "a")
    }
    function test_ignore_list() {
        const x = { key: "org.mpris.MediaPlayer2.firefox.instance_1_2", identity: "Mozilla Firefox", desktopEntry: "firefox" }
        verify(M.isIgnored(x, ["Firefox"]))                     // desktop entry, any case
        verify(M.isIgnored({ key: "org.mpris.MediaPlayer2.spotify", identity: "Spotify", desktopEntry: "" }, ["spotify"]))
        verify(!M.isIgnored(x, ["chromium", ""]))
        verify(!M.isIgnored(x, []))
    }
    function test_no_players() {
        compare(M.pickActive([]), "")
    }

    // An invariant of media refuses the call (any other exception is not a refusal).
    function refuses(f) {
        try { f() } catch (e) { return String(e.message).indexOf("media invariant:") === 0 }
        return false
    }
    function accepts(f) {
        try { f() } catch (e) { return false }
        return true
    }

    function test_invariants_reject_broken_state() {
        verify(refuses(() => M.pickActive([p("a", true, 1, 1), p("a", false, 0, 0)])))
        verify(refuses(() => M.pickActive(null)))
        verify(refuses(() => M.isIgnored(p("a", true, 1, 1), "firefox")))
    }
}
