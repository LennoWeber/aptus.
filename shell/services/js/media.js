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
// played last; players in media.ignore (matched case-insensitively against identity, desktop
// entry and the service name's last part) are never active.
