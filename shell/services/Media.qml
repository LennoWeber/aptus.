pragma Singleton
// Media: players, the active player rule (notch.md §5).
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    property var players: []
    // the active MprisPlayer or null
    property var active: null

    // The active player (05 §7 rule): play/pause, next, previous.
    function toggle(): void { Log.info("service.media", "toggle: not available yet"); }
    function next(): void { Log.info("service.media", "next: not available yet"); }
    function previous(): void { Log.info("service.media", "previous: not available yet"); }
}
