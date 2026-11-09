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
    // TODO(phase): true.
    readonly property bool available: false
    // When the active player paused (ms; 0 while it plays): the compact cover hides after
    // surfaces.notch.compactPausedHideMs.
    property real pausedSince: 0

    // "Hide until it changes" (notch.md §4): the active player's track id when it was hidden; the
    // media activity stays hidden on every monitor until the track changes ("" none).
    // TODO(phase): cleared when the active player's track (or the active player) changes.
    property string hiddenTrack: ""
    // The media activity is hidden now (hiddenTrack is the current track).
    // TODO(phase): hiddenTrack !== "" && hiddenTrack equals the active player's track key.
    readonly property bool hidden: false

    // Player key (D-Bus service name) → { playingSince, lastActive } for the active-player rule.
    property var _seen: ({})

    // TODO(phase): Mpris.players (an Instantiator whose Connections report playbackState
    //   changes to _noteState), media.ignore changes → _rebuild; the first _rebuild at start.

    // The active player (05 §7 rule): play/pause, next, previous.
    // TODO(phase): act on `active` (_touch); a player that cannot do it → nothing; toggle with no
    //   player at all → the event "Nothing to play" (notch.md §5: XF86AudioPlay only).
    function toggle(): void { Log.info("service.media", "toggle: not available yet"); }
    function next(): void { Log.info("service.media", "next: not available yet"); }
    function previous(): void { Log.info("service.media", "previous: not available yet"); }
    // The media card's controls on the active player (notch.md §5): seek to seconds, shuffle,
    // loop None → Playlist → Track → None; only what the player supports.
    function seek(position: real): void { throw new Error("not implemented"); }
    function toggleShuffle(): void { throw new Error("not implemented"); }
    function cycleLoop(): void { throw new Error("not implemented"); }

    // Rebuild `players` and pick `active` (media.js pickActive).
    function _rebuild(): void { throw new Error("not implemented"); }
    // A player's playback state changed (entered Playing, paused).
    function _noteState(player: var): void { throw new Error("not implemented"); }
    // "Hide until it changes": remember the active player's current track.
    function hideUntilChanged(): void { throw new Error("not implemented"); }
    // A player was controlled (keys, card): its lastActive is now.
    function _touch(player: var): void { throw new Error("not implemented"); }
}
