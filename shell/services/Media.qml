pragma Singleton
// Media: players, the active player rule (notch.md §5).
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // the MprisPlayers that are not ignored (media.ignore)
    property var players: []
    // the active MprisPlayer or null
    property var active: null
    // The service works (S3).
    readonly property bool available: false
    // When the active player paused (ms; 0 while it plays): the compact cover hides after
    // surfaces.notch.compactPausedHideMs.
    property real pausedSince: 0

    // Player key (D-Bus service name) → { playingSince, lastActive } for the active-player rule.
    property var _seen: ({})

    // The active player (05 §7 rule): play/pause, next, previous.
    function toggle(): void { Log.info("service.media", "toggle: not available yet"); }
    function next(): void { Log.info("service.media", "next: not available yet"); }
    function previous(): void { Log.info("service.media", "previous: not available yet"); }
}
