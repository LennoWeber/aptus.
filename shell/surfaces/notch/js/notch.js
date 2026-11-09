.pragma library
.import "../../../core/js/format.js" as F
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

// The view for a monitor state (MonitorState fields as a plain object). hoverCard: the activity
// whose card is open by hover ("" none); interactive notch modes and pinned cards come from
// state.notch. A toast whose payload has `card` is a result card (kind "result").
function viewOf(state, hoverCard, isActive) { throw new Error("not implemented") }
// The identity of a view: two views with the same key are one layer updated in place.
function keyOf(view) { throw new Error("not implemented") }
// The layers after the view changed: { layers, serial } (the old current layer leaves, a new one
// enters; the same key keeps the layer; "rest"/"hidden" leave everything).
function nextLayers(layers, view, serial) { throw new Error("not implemented") }
// The layers without the one that finished leaving.
function dropLayer(layers, uid) { throw new Error("not implemented") }
// The compact slots (notch.md §4): per slot the live candidate with the highest priority; when
// the centre group would exceed maxWidth, the lower-priority slot gives way.
function assignSlots(candidates, clockWidth, gap, maxWidth) { throw new Error("not implemented") }
// The toast bulge size (notch.md §6: 72 / 104 / 132 by actions and image).
function toastHeight(payload, heights) { throw new Error("not implemented") }
// The event bulge width: the content's width clamped to 260–360.
function eventWidth(contentWidth, min, max) { throw new Error("not implemented") }
// Countdowns (notch.md §6: pause on hover and while covered, resume with ≥ resumeMin left).
function countdownStart(total, now) { throw new Error("not implemented") }
function countdownPause(c, now) { throw new Error("not implemented") }
function countdownResume(c, now, resumeMin) { throw new Error("not implemented") }
function countdownLeft(c, now) { throw new Error("not implemented") }
// The pager's next activity from `current` among the live ids (Tab, ←/→).
function pagerStep(ids, current, delta) { throw new Error("not implemented") }
// The rest clock's tooltip "Saturday, 7 November · week 45" (core/js/format.js dateLong, isoWeek).
function longDate(date) { throw new Error("not implemented") }
