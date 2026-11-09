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
// The toast bulge height (notch.md §6: 72 / 104 / 132 by actions and image).
function toastHeight(payload, heights) { throw new Error("not implemented") }
// The bulge size { width, height } of a view kind (notch.md §5–§8): toast 420 × toastHeight, OSD
// 300 × 44, event the content width clamped to 260–360 × 36, card and result 420 × the card's
// height (+ the pager when more than one activity is live), mode the mode's own size; rest and
// hidden 0 × 0. measured: { width, height, pager: bool } of the content; tokens: Tokens.surfaces.
function bulgeSize(kind, payload, measured, tokens) { throw new Error("not implemented") }
// The passive timers (notch.md §6–§8, rules.js limits): which entries are due now and when the
// next one is. passive: the monitor's entries; shown: the id of the entry on screen (0 none);
// eventShownAt: when that event first showed; pinnedSince: when the pointer last left a pinned
// card (0 not pinned or under the pointer); timing: { osdMs, eventMs, pinnedMs }.
// → { due: [entry id], card: bool (the pinned card is due), next: ms | 0 }.
// An OSD is due osdMs after its `born` (shown or not: one posted under a mode never shows late).
function dueEntries(passive, shown, eventShownAt, pinnedSince, now, timing) { throw new Error("not implemented") }
// Countdowns (notch.md §6: pause on hover and while covered, resume with ≥ resumeMin left).
function countdownStart(total, now) { throw new Error("not implemented") }
function countdownPause(c, now) { throw new Error("not implemented") }
function countdownResume(c, now, resumeMin) { throw new Error("not implemented") }
function countdownLeft(c, now) { throw new Error("not implemented") }
// The pager's next activity from `current` among the live ids (Tab, ←/→).
function pagerStep(ids, current, delta) { throw new Error("not implemented") }
// The rest clock's tooltip "Saturday, 7 November · week 45" (core/js/format.js dateLong, isoWeek).
function longDate(date) { throw new Error("not implemented") }
