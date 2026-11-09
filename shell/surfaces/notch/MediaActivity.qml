// The media activity: still cover in the left slot, the media card (notch.md §4–§5).
// Owner: S3. Live while the active player plays, or paused for less than 10 minutes.
import QtQuick
import qs.components

Activity {
    id: root

    activity: "media"
    slot: "left"

    // The active MprisPlayer (Media.active), or null.
    // TODO(phase): Media.active.
    readonly property var player: null
    // Paused (priority mediaPaused, cover at 40 % under ink.faint).
    // TODO(phase): the player is not playing (Media.pausedSince > 0).
    readonly property bool paused: false
    // Hidden by "Hide until it changes" until the track changes.
    property string _hiddenTrack: ""

    // Middle click: play/pause (notch.md §4).
    function middleClick(): void { throw new Error("not implemented"); }
    // The right-click menu's own row: Hide until it changes (the Notch adds Open in Today).
    function menuTriggered(row: var): void { throw new Error("not implemented"); }

    // TODO(phase): live while the player plays, or paused for less than compactPausedHideMs, and
    //   its track is not _hiddenTrack; priority media / mediaPaused; compact MediaCompact, card
    //   MediaCard; menu [Hide until it changes]; a Timer for the paused hide.
}
