.pragma library
// The notification logic of surfaces/notch.md §6 and 05-interaction §8, as pure functions over
// plain objects. Notifications.qml keeps the live Quickshell objects and calls these.
//
// A record (Today's history entry, newest first in Notifications.history):
//   { id: int (the server's id; injected ones count down from -1), appName, appIcon, desktopEntry,
//     summary, body (reduced markup: <b> <i> <a href>), image: url string | "",
//     urgency: 0 low | 1 normal | 2 critical, actions: [{ id, text }] (without "default"),
//     hasDefault: bool, resident: bool, reply: bool (inline-reply action), progress: -1 | 0..100,
//     time: ms since the epoch (arrival or last replace), read: bool, live: bool (the sender
//     still tracks it; actions work) }
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
// The held summary's wording per hold reason (05 §8).
var HELD_WHILE = { focus: "while you were focused", dnd: "during Do not disturb", fullscreen: "while in fullscreen" }
// Tags the body keeps (notch.md §6: bold, italic, links).
var KEEP_TAGS = ["b", "i", "a"]

// A record from the plain fields of a notification (the QML side reads them off the object).
function makeRecord(src, now) { throw new Error("not implemented") }
// The policy decision for a record (05 §8).
function decide(record, ctx) { throw new Error("not implemented") }
// The app is on notifications.allowlist (by app name or desktop entry, case-insensitive).
function isAllowlisted(record, allowlist) { throw new Error("not implemented") }
// The app is muted at `now`.
function isMuted(record, muted, now) { throw new Error("not implemented") }
// Toast timeout in ms (notch.md §6; 0 = until dismissed). setting: notifications.timeout
// ("auto" | seconds); timing: Tokens.surfaces.toast.
function toastTimeout(record, setting, timing) { throw new Error("not implemented") }
// The toast payload of a record.
function toastPayload(record, timeout, maxActions) { throw new Error("not implemented") }
// The stack after an arrival: { stack, joins: bool } (joins: the arrival updates the stack toast
// instead of posting its own).
function stackStep(stack, record, passiveId, monitor, now, windowMs) { throw new Error("not implemented") }
// The payload of the stack toast with its newest record.
function stackPayload(stack, newest, timeout) { throw new Error("not implemented") }
// The summary toast for `count` held notifications.
function heldPayload(count, reason, timeout) { throw new Error("not implemented") }
// Body markup reduced to <b>, <i> and <a href>; everything else escaped or dropped.
function reduceMarkup(body) { throw new Error("not implemented") }
// The visible text of reduced markup (for the timeout's character count).
function plainText(markup) { throw new Error("not implemented") }
// The progress hint (`value` 0–100) or -1.
function progressOf(hints) { throw new Error("not implemented") }
// History operations (new arrays; history newest first).
function addToHistory(history, record, max, days, now) { throw new Error("not implemented") }
function trimHistory(history, max, days, now) { throw new Error("not implemented") }
function markRead(history, id) { throw new Error("not implemented") }
function markAllRead(history) { throw new Error("not implemented") }
function removeRecord(history, id) { throw new Error("not implemented") }
// { unread: int, allowlisted: bool } for the unread dot.
function unreadInfo(history, allowlist) { throw new Error("not implemented") }
// Persistence: the state file's JSON text, and the history read back (records not live).
function serialise(history) { throw new Error("not implemented") }
function parse(text, now, max, days) { throw new Error("not implemented") }
