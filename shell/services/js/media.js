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
    var best = null
    for (var i = 0; i < players.length; i++) {
        var p = players[i]
        if (p.playing && (!best || !best.playing || p.playingSince > best.playingSince)) best = p
    }
    if (best) return best.key
    for (var j = 0; j < players.length; j++) {
        var q = players[j]
        if (!best || q.lastActive > best.lastActive) best = q
    }
    return best ? best.key : ""
}
// The player is listed in media.ignore.
function isIgnored(player, ignore) {
    invariant(Array.isArray(ignore), "media.ignore is not a list")
    var list = ignore || []
    var key = String(player.key || "")
    var names = [String(player.identity || "").toLowerCase(), String(player.desktopEntry || "").toLowerCase(),
                 key.substring(key.lastIndexOf(".") + 1).toLowerCase()]
    for (var i = 0; i < list.length; i++) {
        var x = String(list[i] || "").toLowerCase()
        if (x !== "" && names.indexOf(x) >= 0) return true
    }
    return false
}

// Invariants (phase 6): they throw "media invariant: …".
function invariant(cond, message) { if (!cond) throw new Error("media invariant: " + message) }
