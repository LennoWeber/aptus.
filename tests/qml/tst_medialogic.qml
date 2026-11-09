// The active-player rule (services/js/media.js, notch.md §5).
import QtQuick
import QtTest
import "../../shell/services/js/media.js" as M

TestCase {
    name: "medialogic"

    function test_most_recent_playing_wins() { skip("phase 7") }
    function test_none_playing_last_played() { skip("phase 7") }
    function test_ignore_list() { skip("phase 7") }
    function test_no_players() { skip("phase 7") }
}
