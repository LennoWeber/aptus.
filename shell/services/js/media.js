.pragma library
// The media logic of surfaces/notch.md §4–§5: which player is the active one, and the time texts
// of the media card. Media.qml keeps the MprisPlayer objects and calls these.
//
// A player summary (what the rule needs, built per MprisPlayer):
//   { key: string (the player's D-Bus service name), identity, desktopEntry, playing: bool,
//     playingSince: ms (when it last entered Playing; 0 never), lastActive: ms (last time it
//     played or was controlled; 0 never) }
//
// The active player: the one that most recently entered Playing; if none plays, the one that
// played last. Players in media.ignore (matched case-insensitively against identity, desktop
// entry and the service name's last part) never reach the rule: Media._rebuild leaves them out
// of `players` with isIgnored.
// (The card's time texts are core/js/format.js clockDuration.)

// The key of the active player among summaries (already without ignored players), or "".
function pickActive(players) {
    invariant(Array.isArray(players), "players is not a list")
    invariant(players.every(function (p, i) { return players.map(function (q) { return q.key }).indexOf(p.key) === i }), "a player twice")
    throw new Error("not implemented")
}
// The player is listed in media.ignore.
function isIgnored(player, ignore) {
    invariant(Array.isArray(ignore), "media.ignore is not a list")
    throw new Error("not implemented")
}

// Invariants (phase 6): they throw "media invariant: …".
function invariant(cond, message) { if (!cond) throw new Error("media invariant: " + message) }
