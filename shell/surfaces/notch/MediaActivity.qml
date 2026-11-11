pragma ComponentBehavior: Bound
// The media activity: still cover in the left slot, the media card (notch.md §4–§5).
// Owner: S3. Live while the active player plays, or paused for less than 10 minutes.
import QtQuick
import qs.core
import qs.services
import qs.components

Activity {
    id: root

    activity: "media"
    slot: "left"
    // The active MprisPlayer (Media.active), or null.
    readonly property var player: Media.active
    // Paused (priority mediaPaused, cover at 40 % under ink.faint).
    readonly property bool paused: player !== null && !player.isPlaying
    // The paused cover hides compactPausedHideMs after the pause (one timer, no polling).
    property bool _pausedLong: false

    live: player !== null && !Media.hidden && !(paused && _pausedLong)
    priority: Tokens.surfaces.notch.activityPriorities[paused ? "mediaPaused" : "media"]
    compact: Component { MediaCompact {} }
    card: Component { MediaCard {} }
    menu: [{ id: "hide", label: "Hide until it changes", glyph: "visibility_off" }]

    // Middle click: play/pause (notch.md §4).
    function middleClick(): void { Media.toggle(); }
    // The right-click menu's own row: Hide until it changes (the Notch adds Open in Today).
    function menuTriggered(row: var): void { if (row && row.id === "hide") Media.hideUntilChanged(); }

    readonly property real _pausedSince: Media.pausedSince
    on_PausedSinceChanged: _armPaused()
    // Found in review: also at creation (a Notch made while the player is already paused: a
    // start, a monitor added), where the change handler does not run.
    Component.onCompleted: _armPaused()
    function _armPaused(): void {
        _pausedLong = false;
        if (_pausedSince > 0) {
            _timer.interval = Math.max(0, _pausedSince + Tokens.surfaces.notch.compactPausedHideMs - Date.now());
            _timer.restart();
        } else _timer.stop();
    }
    property Timer _timer: Timer {
        onTriggered: root._pausedLong = true
    }
}
