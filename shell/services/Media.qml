pragma Singleton
pragma ComponentBehavior: Bound
// Media: players, the active player rule (notch.md §5).
// Owner: S3.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.core
import "js/media.js" as M

Singleton {
    id: root

    // the MprisPlayers that are not ignored (media.ignore)
    property var players: []
    // the active MprisPlayer or null
    property var active: null
    // The service works (S3).
    readonly property bool available: true
    // When the active player paused (ms; 0 while it plays): the compact cover hides after
    // surfaces.notch.compactPausedHideMs.
    property real pausedSince: 0
    // "Hide until it changes" (notch.md §4): the active player's track key when it was hidden;
    // the media activity stays hidden on every monitor until the track changes ("" none).
    property string hiddenTrack: ""
    // The active player's track key (service name, title, artist).
    readonly property string trackKey: active ? [active.dbusName, active.trackTitle, active.trackArtist].join("|") : ""
    // The media activity is hidden now (hiddenTrack is the current track).
    readonly property bool hidden: hiddenTrack !== "" && hiddenTrack === trackKey
    onTrackKeyChanged: if (hiddenTrack !== "" && hiddenTrack !== trackKey) hiddenTrack = ""

    // Player key (D-Bus service name) → { playingSince, lastActive } for the active-player rule.
    property var _seen: ({})

    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPlaybackStateChanged(): void { root._noteState(modelData); }
        }
        onObjectAdded: root._rebuild()
        onObjectRemoved: root._rebuild()
    }
    Connections {
        target: Config
        function onSettingChanged(key: string): void { if (key === "media.ignore") root._rebuild(); }
    }
    Component.onCompleted: _rebuild()

    // The active player (05 §7 rule): play/pause, next, previous.
    function toggle(): void {
        if (!active) { _nothing(); return; }
        if (active.canTogglePlaying) { active.togglePlaying(); _touch(active); }
    }
    function next(): void { if (active && active.canGoNext) { active.next(); _touch(active); } }
    function previous(): void { if (active && active.canGoPrevious) { active.previous(); _touch(active); } }
    // The media card's controls on the active player (notch.md §5): seek to seconds, shuffle,
    // loop None → Playlist → Track → None; only what the player supports.
    function seek(position: real): void {
        if (active && active.canSeek && active.positionSupported) { active.position = position; _touch(active); }
    }
    function toggleShuffle(): void { if (active && active.shuffleSupported) { active.shuffle = !active.shuffle; _touch(active); } }
    function cycleLoop(): void {
        if (!active || !active.loopSupported) return;
        const s = active.loopState;
        active.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
        _touch(active);
    }
    // "Hide until it changes": remember the active player's current track.
    function hideUntilChanged(): void { hiddenTrack = trackKey; }
    // XF86AudioPlay with no player at all (notch.md §5).
    function _nothing(): void { SurfaceManager.post("event", { text: "Nothing to play", glyph: "music_off" }); }

    // A player as the plain record media.js works on (dbusName, identity, playbackState, …).
    function _summary(p: var): var {
        const s = _seen[p.dbusName] || { playingSince: 0, lastActive: 0 };
        return { key: p.dbusName, identity: p.identity, desktopEntry: p.desktopEntry, playing: p.isPlaying,
                 playingSince: s.playingSince, lastActive: s.lastActive };
    }
    // Rebuild `players` and pick `active` (media.js pickActive).
    function _rebuild(): void {
        const ignore = Config.get("media.ignore") || [];
        const list = Mpris.players.values.filter(p => !M.isIgnored(_summary(p), ignore));
        players = list;
        const key = M.pickActive(list.map(p => _summary(p)));
        const a = list.find(p => p.dbusName === key) || null;
        if (a !== active) active = a;
        pausedSince = a && !a.isPlaying ? (pausedSince || Date.now()) : 0;
    }
    // A player's playback state changed (entered Playing, paused).
    function _noteState(player: var): void {
        const seen = Object.assign({}, _seen);
        const s = Object.assign({ playingSince: 0, lastActive: 0 }, seen[player.dbusName] || {});
        const now = Date.now();
        if (player.isPlaying) { s.playingSince = now; s.lastActive = now; }
        else if (s.playingSince > 0) s.lastActive = now;
        seen[player.dbusName] = s;
        _seen = seen;
        if (player === active && !player.isPlaying) pausedSince = now;
        _rebuild();
    }
    // A player was controlled (keys, card): its lastActive is now.
    function _touch(player: var): void {
        const seen = Object.assign({}, _seen);
        const s = Object.assign({ playingSince: 0, lastActive: 0 }, seen[player.dbusName] || {});
        s.lastActive = Date.now();
        seen[player.dbusName] = s;
        _seen = seen;
    }
}
