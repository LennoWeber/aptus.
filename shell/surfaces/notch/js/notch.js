.pragma library
// The notch's presenter logic (surfaces/notch.md §2–§10) as pure functions: which content the
// bulge shows, its size, the compact slots, the toast countdown and the passive timers.
//
// A layer (one content on screen; the current one plus those still fading out, notch.md §10):
//   { uid: int, kind: "toast" | "osd" | "event" | "card" | "result" | "mode",
//     key: string (identity: same key → updated in place, new key → crossfade),
//     entryId: int (the passive entry, 0 for cards and modes), activity: "" | id (card),
//     mode: "" | notch-mode id, leaving: bool }
//
// What the notch shows (the presenter's view of MonitorState):
//   { kind: "rest" | "hidden" | "toast" | "osd" | "event" | "card" | "result" | "mode",
//     key, entry: passive entry | null, activity: "", mode: "" }
//
// A countdown (toast timing, notch.md §6): { total: ms (0 = none), remaining: ms,
//   running: bool, since: ms (when it last resumed) }.
//
// A slot assignment (notch.md §4): { left: activity id | "", right: activity id | "",
//   waiting: [id] } from candidates [{ id, slot, priority, width }].
