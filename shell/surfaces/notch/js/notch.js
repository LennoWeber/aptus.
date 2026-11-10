.pragma library
.import "../../../core/js/format.js" as F
.import "../../../core/js/rules.js" as R
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
function viewOf(state, hoverCard, isActive) {
    invariant(state && R.legalNotch(state.notch), "illegal notch state " + (state && state.notch))
    invariant(!state.passiveTop || TOP_KINDS.indexOf(state.passiveTop.kind) >= 0, "illegal passive top " + (state.passiveTop && state.passiveTop.kind))
    throw new Error("not implemented")
}
// The identity of a view: two views with the same key are one layer updated in place.
function keyOf(view) {
    invariant(view && VIEW_KINDS.indexOf(view.kind) >= 0, "illegal view kind " + (view && view.kind))
    invariant(ENTRY_KINDS.indexOf(view.kind) < 0 || !!view.entry, "a " + view.kind + " view without its entry")
    throw new Error("not implemented")
}
// The layers after the view changed: { layers, serial } (the old current layer leaves, a new one
// enters; the same key keeps the layer; "rest"/"hidden" leave everything).
function nextLayers(layers, view, serial) {
    checkLayers(layers)
    invariant(layers.every(function (l) { return l.uid <= serial }), "serial " + serial + " behind a layer uid")
    checkView(view)
    // TODO(phase): checkNext(view, serial, result).
    throw new Error("not implemented")
}
// The layers without the one that finished leaving.
function dropLayer(layers, uid) {
    checkLayers(layers)
    invariant(layers.every(function (l) { return l.uid !== uid || l.leaving }), "layer " + uid + " is current")
    throw new Error("not implemented")
}
// The compact slots (notch.md §4): per slot the live candidate with the highest priority; when
// the centre group would exceed maxWidth, the lower-priority slot gives way.
function assignSlots(candidates, clockWidth, gap, maxWidth) {
    checkCandidates(candidates)
    invariant(clockWidth >= 0 && gap >= 0 && maxWidth > 0, "slot geometry " + [clockWidth, gap, maxWidth])
    // TODO(phase): checkSlots(result, candidates).
    throw new Error("not implemented")
}
// The toast bulge height (notch.md §6: 72 / 104 / 132 by actions and image).
function toastHeight(payload, heights) {
    invariant(Array.isArray(heights) && heights.length === 3 && heights[0] > 0 && heights[0] <= heights[1] && heights[1] <= heights[2], "toast heights " + heights)
    throw new Error("not implemented")
}
// The bulge size { width, height } of a view kind (notch.md §5–§8): toast 420 × toastHeight, OSD
// 300 × 44, event the content width clamped to 260–360 × 36, card and result 420 × the card's
// height (+ the pager when more than one activity is live), mode the mode's own size; rest and
// hidden 0 × 0. measured: { width, height, pager: bool } of the content; tokens: Tokens.surfaces.
function bulgeSize(kind, payload, measured, tokens) {
    invariant(VIEW_KINDS.indexOf(kind) >= 0, "illegal view kind " + kind)
    invariant(tokens && tokens.toast && tokens.osd && tokens.event && tokens.card, "surface tokens missing")
    invariant(tokens.event.minWidth <= tokens.event.maxWidth, "event width range " + tokens.event.minWidth + ".." + tokens.event.maxWidth)
    throw new Error("not implemented")
}
// The passive timers (notch.md §6–§8, rules.js limits): which entries are due now and when the
// next one is. passive: the monitor's entries; shown: the id of the entry on screen (0 none);
// eventShownAt: when that event first showed; pinnedSince: when the pointer last left a pinned
// card (0 not pinned or under the pointer); timing: { osdMs, eventMs, pinnedMs }.
// → { due: [entry id], card: bool (the pinned card is due), next: ms | 0 }.
// An OSD is due osdMs after its `born` (shown or not: one posted under a mode never shows late).
function dueEntries(passive, shown, eventShownAt, pinnedSince, now, timing) {
    checkPassive(passive)
    invariant(passive.length === 0 || (timing.osdMs > 0 && timing.eventMs > 0), "passive timing " + timing.osdMs + "/" + timing.eventMs)
    invariant(pinnedSince <= 0 || timing.pinnedMs > 0, "pinned timing " + timing.pinnedMs)
    throw new Error("not implemented")
}
// Countdowns (notch.md §6: pause on hover and while covered, resume with ≥ resumeMin left).
function countdownStart(total, now) {
    invariant(total >= 0, "negative countdown " + total)
    throw new Error("not implemented")
}
function countdownPause(c, now) {
    checkCountdown(c)
    throw new Error("not implemented")
}
function countdownResume(c, now, resumeMin) {
    checkCountdown(c)
    invariant(resumeMin >= 0, "negative resume minimum " + resumeMin)
    throw new Error("not implemented")
}
function countdownLeft(c, now) {
    checkCountdown(c)
    throw new Error("not implemented")
}
// The pager's next activity from `current` among the live ids (Tab, ←/→).
function pagerStep(ids, current, delta) {
    invariant(unique(ids), "pager ids twice: " + ids)
    invariant(delta === 1 || delta === -1, "pager delta " + delta)
    throw new Error("not implemented")
}
// The rest clock's tooltip "Saturday, 7 November · week 45" (core/js/format.js dateLong, isoWeek).
function longDate(date) {
    invariant(date instanceof Date && !isNaN(date.getTime()), "not a date: " + date)
    throw new Error("not implemented")
}

// Invariants (phase 6): states the presenter must never reach. They throw "notch invariant: …";
// the public functions check their input, Notch.qml's results pass the check* functions too.
var VIEW_KINDS = ["rest", "hidden", "toast", "osd", "event", "card", "result", "mode"]
// The kinds rules.js arbitrate reports, and the view kinds that carry a passive entry.
var TOP_KINDS = ["rest", "hidden", "osd", "toast", "event", "card"]
var ENTRY_KINDS = ["toast", "result", "osd", "event"]
function invariant(cond, message) { if (!cond) throw new Error("notch invariant: " + message) }
function unique(list) {
    for (var i = 0; i < list.length; i++) if (list.indexOf(list[i]) !== i) return false
    return true
}
// Layers: positive unique uids, a key and a layer kind each (rest and hidden are no layer), at
// most one current (not leaving) layer: two contents never enter at once (notch.md §10).
function checkLayers(layers) {
    invariant(Array.isArray(layers), "layers is not a list")
    var current = 0
    for (var i = 0; i < layers.length; i++) {
        var l = layers[i]
        invariant(l && l.uid > 0, "layer without a uid")
        invariant(VIEW_KINDS.indexOf(l.kind) >= 2, "illegal layer kind " + l.kind)
        invariant(typeof l.key === "string" && l.key !== "", "layer " + l.uid + " without a key")
        if (!l.leaving) current++
    }
    invariant(unique(layers.map(function (l) { return l.uid })), "layer uids twice")
    invariant(current <= 1, current + " current layers")
}
// A view: its key is keyOf(view); an entry kind has its entry, a card its activity, a mode its
// mode; rest and hidden have none of them.
function checkView(view) {
    invariant(view && VIEW_KINDS.indexOf(view.kind) >= 0, "illegal view kind " + (view && view.kind))
    invariant(view.key === keyOf(view), "view key " + view.key + " is not its identity")
    invariant(view.kind !== "card" || ACTIVITY_IDS.indexOf(view.activity) >= 0, "card of an unknown activity " + view.activity)
    invariant(view.kind !== "mode" || R.NOTCH_MODES.indexOf(view.mode) >= 0, "unknown mode " + view.mode)
    invariant(view.kind !== "rest" && view.kind !== "hidden" || (!view.entry && view.activity === "" && view.mode === ""),
              view.kind + " view with content")
}
var ACTIVITY_IDS = R.ACTIVITIES
// Slot candidates: known activities, each once, a slot side, a width, a priority.
function checkCandidates(candidates) {
    invariant(Array.isArray(candidates), "candidates is not a list")
    for (var i = 0; i < candidates.length; i++) {
        var c = candidates[i]
        invariant(c && ACTIVITY_IDS.indexOf(c.id) >= 0, "candidate of an unknown activity " + (c && c.id))
        invariant(c.slot === "left" || c.slot === "right", "candidate " + c.id + " slot " + c.slot)
        invariant(c.width >= 0 && isFinite(c.priority), "candidate " + c.id + " width/priority")
    }
    invariant(unique(candidates.map(function (c) { return c.id })), "an activity is a candidate twice")
}
// The layers after a view: checkLayers; the serial never goes back; rest and hidden leave no
// current layer, any other view exactly one, and it is the view's (its key).
function checkNext(view, serial, result) {
    checkLayers(result.layers)
    invariant(result.serial >= serial, "serial went back to " + result.serial)
    var current = result.layers.filter(function (l) { return !l.leaving })
    if (view.kind === "rest" || view.kind === "hidden") invariant(current.length === 0, "a current layer at " + view.kind)
    else invariant(current.length === 1 && current[0].key === view.key, "the view " + view.key + " has no current layer")
}
// A slot assignment: every candidate exactly once (in a slot or waiting), the slots on their
// own side.
function checkSlots(slots, candidates) {
    invariant(slots.left === "" || slots.left !== slots.right, "one activity in both slots")
    var placed = (slots.left ? [slots.left] : []).concat(slots.right ? [slots.right] : [], slots.waiting)
    invariant(placed.length === candidates.length && unique(placed)
              && candidates.every(function (c) { return placed.indexOf(c.id) >= 0 }), "a candidate is lost or shown twice")
    var side = function (id) { return candidates.filter(function (c) { return c.id === id })[0].slot }
    invariant((!slots.left || side(slots.left) === "left") && (!slots.right || side(slots.right) === "right"),
              "an activity in the other side's slot")
}
// Passive entries (rules.js): legal kinds, unique ids, a birth time.
function checkPassive(passive) {
    invariant(Array.isArray(passive), "passive is not a list")
    for (var i = 0; i < passive.length; i++) {
        var e = passive[i]
        invariant(e && R.PASSIVE_KINDS.indexOf(e.kind) >= 0, "illegal passive kind " + (e && e.kind))
        invariant(e.id > 0 && isFinite(e.born), "passive entry without id or birth")
    }
    invariant(unique(passive.map(function (e) { return e.id })), "passive ids twice")
}
// A countdown: total ≥ 0, a finite remainder; one without a total never runs (critical toasts).
function checkCountdown(c) {
    invariant(c && c.total >= 0 && isFinite(c.remaining) && isFinite(c.since), "broken countdown")
    invariant(c.total > 0 || !c.running, "a countdown without a total runs")
}
