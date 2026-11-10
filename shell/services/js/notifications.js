.pragma library
// The notification logic of surfaces/notch.md §6 and 05-interaction §8, as pure functions over
// plain objects. Notifications.qml keeps the live Quickshell objects and calls these.
//
// A record (Today's history entry, newest first in Notifications.history):
//   { id: int (the server's id; injected ones count down from -1; one read back from the state
//     file has ARCHIVE_ID − its index: server ids start at 1 again with every shell start),
//     appName, appIcon, desktopEntry,
//     summary, body (reduced markup: <b> <i> <a href>), image: url string | "",
//     urgency: 0 low | 1 normal | 2 critical, actions: [{ id, text }] (without "default"),
//     hasDefault: bool, resident: bool, reply: bool (inline-reply action), progress: -1 | 0..100,
//     time: ms since the epoch (arrival or last replace), read: bool, live: bool (the sender
//     still tracks it; actions work), held: "" | "dnd" | "focus" | "fullscreen" (why it did
//     not toast; Today's "Held during focus" subtitle, today.md §6) }
//
// The policy context (what decides whether a toast shows, 05 §8):
//   { dnd: bool, focus: bool, fullscreen: bool (on the active monitor), overFullscreen:
//     "critical" | "none" | "all", allowlist: [app], muted: { app: until ms }, now: ms }
//
// A decision: { show: "toast" | "today" | "held" | "progress", priority: 0 | 2, reason:
//   "" | "dnd" | "focus" | "fullscreen" | "low" | "muted" }
//
// A toast payload (SurfaceManager.post("toast", payload, priority, monitor, "n:<id>")):
//   { nid: int (record id; 0 for a system toast), appName, appIcon, summary, body, image,
//     critical: bool, actions: [{ id, text }] (≤ toast.maxActions), hasDefault, resident, reply,
//     timeout: ms (0 = until dismissed), time, stack: null | { count, icons: [appIcon], apps:
//     [appName] }, opens: "" | "today" (a click opens Today: the stack and the held summary),
//     glyph: "" (a system toast's glyph instead of the app icon, e.g. "battery_alert") }
//
// The stack (notch.md §6 arrival rule 2): { passiveId, monitor, count, icons, apps, last: ms }.

// Urgency levels (freedesktop) and the passive priority of a critical toast (rules.js: ≥ 2).
var LOW = 0, NORMAL = 1, CRITICAL = 2
var CRITICAL_PRIORITY = 2
// "Mute App for 1 hour" (notch.md §6).
var MUTE_MS = 3600000
// A notification without app name or icon (notch.md §12).
var FALLBACK_APP = "Notification"
var FALLBACK_GLYPH = "notifications"
// The ids of records read back from the state file (ARCHIVE_ID, ARCHIVE_ID − 1, …): below every
// server id (≥ 1) and every injected one (−1 down), so a new notification never replaces an old
// record.
var ARCHIVE_ID = -1000000
// The held summary's wording per hold reason (05 §8).
var HELD_WHILE = { focus: "while you were focused", dnd: "during Do not disturb", fullscreen: "while in fullscreen" }
// Tags the body keeps (notch.md §6: bold, italic, links).
var KEEP_TAGS = ["b", "i", "a"]

// A record from the plain fields of a notification (the QML side reads them off the object).
function makeRecord(src, now) {
    invariant(src && typeof src === "object", "no source")
    invariant(isFinite(now), "no time")
    throw new Error("not implemented")
}
// The policy decision for a record (05 §8).
function decide(record, ctx) {
    checkRecord(record)
    checkContext(ctx)
    // TODO(phase): checkDecision(record, result): critical is never held, and keeps priority 2
    //   also as progress (a progress the Progress service refuses falls back to a toast).
    throw new Error("not implemented")
}
// The app is on notifications.allowlist (by app name or desktop entry, case-insensitive).
function isAllowlisted(record, allowlist) {
    invariant(!allowlist || Array.isArray(allowlist), "allowlist is not a list")
    throw new Error("not implemented")
}
// The app is muted at `now`.
function isMuted(record, muted, now) {
    invariant(!muted || typeof muted === "object", "muted is not a map")
    throw new Error("not implemented")
}
// Toast timeout in ms (notch.md §6; 0 = until dismissed). setting: notifications.timeout
// ("auto" | seconds); timing: Tokens.surfaces.toast.
function toastTimeout(record, setting, timing) {
    checkRecord(record)
    checkTiming(timing)
    invariant(setting === "auto" || Number(setting) >= 0, "toast timeout setting " + setting)
    throw new Error("not implemented")
}
// The toast payload of a record.
function toastPayload(record, timeout, maxActions) {
    checkRecord(record)
    invariant(timeout >= 0 && maxActions >= 0, "toast timeout " + timeout + ", max actions " + maxActions)
    throw new Error("not implemented")
}
// The stack after an arrival: { stack, joins: bool } (joins: the arrival updates the stack toast
// instead of posting its own).
function stackStep(stack, record, passiveId, monitor, now, windowMs) {
    checkRecord(record)
    if (stack) checkStack(stack)
    invariant(passiveId >= 0 && windowMs >= 0, "stack id " + passiveId + ", window " + windowMs)
    throw new Error("not implemented")
}
// The payload of the stack toast with its newest record.
function stackPayload(stack, newest, timeout) {
    checkStack(stack)
    invariant(stack.count >= 2 && stack.passiveId > 0, "a stack toast for " + stack.count + " notification(s)")
    checkRecord(newest)
    throw new Error("not implemented")
}
// The summary toast for `count` held notifications.
function heldPayload(count, reason, timeout) {
    invariant(count >= 1, "held summary of " + count)
    invariant(isHoldReason(reason), "unknown hold reason " + reason)
    throw new Error("not implemented")
}
// A toast the shell raises itself (no notification behind it: battery, urgent workspace): a
// toast payload with nid 0, the glyph instead of the app icon, no actions.
function systemToast(title, body, glyph, critical, timeout) {
    invariant(typeof title === "string" && title !== "", "system toast without a title")
    invariant(critical || timeout > 0, "system toast without a timeout")
    throw new Error("not implemented")
}
// Body markup reduced to <b>, <i> and <a href>; everything else escaped or dropped.
function reduceMarkup(body) {
    invariant(typeof body === "string", "body is not a string")
    throw new Error("not implemented")
}
// The visible text of reduced markup (for the timeout's character count).
function plainText(markup) {
    invariant(typeof markup === "string", "markup is not a string")
    throw new Error("not implemented")
}
// The progress hint (`value` 0–100) or -1.
function progressOf(hints) { throw new Error("not implemented") }
// History operations (new arrays; history newest first).
function addToHistory(history, record, max, days, now) {
    checkHistory(history)
    checkRecord(record)
    invariant(max >= 1 && days >= 1, "history limits " + max + "/" + days)
    // TODO(phase): checkHistory(result).
    throw new Error("not implemented")
}
function trimHistory(history, max, days, now) {
    checkHistory(history)
    invariant(max >= 1 && days >= 1, "history limits " + max + "/" + days)
    throw new Error("not implemented")
}
function markRead(history, id) {
    checkHistory(history)
    throw new Error("not implemented")
}
function markAllRead(history) {
    checkHistory(history)
    throw new Error("not implemented")
}
function removeRecord(history, id) {
    checkHistory(history)
    throw new Error("not implemented")
}
// { unread: int, allowlisted: bool } for the unread dot.
function unreadInfo(history, allowlist) {
    checkHistory(history)
    throw new Error("not implemented")
}
// Persistence: the state file's JSON text, and the history read back (records not live).
// keep: the ids the server still tracks at load (after a reload with keepOnReload, which P-23
// limits to APTUS_DEV runs); their records keep their id, every other one gets ARCHIVE_ID − index.
function serialise(history) {
    checkHistory(history)
    throw new Error("not implemented")
}
function parse(text, now, max, days, keep) {
    invariant(typeof text === "string", "state text is not a string")
    invariant(max >= 1 && days >= 1, "history limits " + max + "/" + days)
    invariant(!keep || Array.isArray(keep), "kept ids are not a list")
    // TODO(phase): the file is data: `held` clamped to a hold reason (else ""), a record failing
    //   checkRecord or a second one with an id already read is dropped, never thrown (a throw
    //   would leave the history empty and the next save would overwrite the file); ids re-keyed
    //   except `keep`; checkHistory(result).
    throw new Error("not implemented")
}

// Invariants (phase 6): what the policy and the history must never hold. They throw
// "notifications invariant: …".
var SHOWS = ["toast", "today", "held", "progress"]
var OVER_FULLSCREEN = ["critical", "none", "all"]
function invariant(cond, message) { if (!cond) throw new Error("notifications invariant: " + message) }
// A key of HELD_WHILE itself (not one of Object's: "constructor", "toString").
function isHoldReason(x) { return typeof x === "string" && Object.prototype.hasOwnProperty.call(HELD_WHILE, x) }
// A record: a non-zero integer id, an app name (the fallback at least), a freedesktop urgency,
// actions without "default" and "inline-reply" (they are hasDefault and reply), a progress of -1
// or 0–100, a known hold reason, a time.
function checkRecord(r) {
    invariant(r && typeof r === "object", "no record")
    invariant(r.id !== 0 && Math.floor(r.id) === r.id, "record id " + r.id)
    invariant(typeof r.appName === "string" && r.appName !== "", "record " + r.id + " without an app name")
    invariant(r.urgency === LOW || r.urgency === NORMAL || r.urgency === CRITICAL, "record " + r.id + " urgency " + r.urgency)
    invariant(Array.isArray(r.actions) && r.actions.every(function (a) { return a.id !== "default" && a.id !== "inline-reply" }),
              "record " + r.id + " keeps a default or reply action")
    invariant(r.progress === -1 || (r.progress >= 0 && r.progress <= 100), "record " + r.id + " progress " + r.progress)
    invariant(r.held === "" || isHoldReason(r.held), "record " + r.id + " held " + r.held)
    invariant(isFinite(r.time), "record " + r.id + " without a time")
}
// The policy context: a known notch.overFullscreen, an allowlist, a muted map, a time.
function checkContext(c) {
    invariant(c && OVER_FULLSCREEN.indexOf(c.overFullscreen) >= 0, "overFullscreen " + (c && c.overFullscreen))
    invariant(Array.isArray(c.allowlist) && c.muted && typeof c.muted === "object" && isFinite(c.now), "broken policy context")
}
// A decision for a record: a known outcome; critical is never held or sent to Today, and it has
// priority 2 whatever it shows (a refused progress falls back to a toast with that priority),
// nothing else has (05 §8).
function checkDecision(record, d) {
    invariant(d && SHOWS.indexOf(d.show) >= 0, "decision " + (d && d.show))
    invariant(record.urgency !== CRITICAL || d.show === "toast" || d.show === "progress", "a critical notification is " + d.show)
    invariant((d.priority === CRITICAL_PRIORITY) === (record.urgency === CRITICAL), "priority " + d.priority)
    invariant(d.show !== "held" || isHoldReason(d.reason), "held without a reason")
}
// Toast timing (Tokens.surfaces.toast): positive, min ≤ max.
function checkTiming(t) {
    invariant(t && t.minTimeoutMs > 0 && t.minTimeoutMs <= t.maxTimeoutMs && t.perCharMs >= 0 && t.actionsExtraMs >= 0
              && t.baseTimeoutMs >= 0, "toast timing")
}
// A stack: at least one notification, one to `count` distinct apps, at most three icons.
function checkStack(s) {
    invariant(s && s.count >= 1 && s.passiveId >= 0 && Array.isArray(s.icons) && Array.isArray(s.apps), "broken stack")
    invariant(s.apps.length >= 1 && s.apps.length <= s.count, "stack of " + s.count + " with " + s.apps.length + " apps")
    invariant(s.icons.length <= 3 && s.icons.length <= s.apps.length, "stack icons " + s.icons.length)
    invariant(s.apps.every(function (a, i) { return s.apps.indexOf(a) === i }), "an app twice in a stack")
}
// A history: records, each id once (a replace moves the record, never copies it).
function checkHistory(h) {
    invariant(Array.isArray(h), "history is not a list")
    var seen = {}
    for (var i = 0; i < h.length; i++) {
        checkRecord(h[i])
        invariant(!seen[h[i].id], "history holds " + h[i].id + " twice")
        seen[h[i].id] = true
    }
}
