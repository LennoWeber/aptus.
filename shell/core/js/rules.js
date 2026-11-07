.pragma library
// The surface transition rules of 07-architecture §5 and 05-interaction §2/§3, as pure functions
// over plain objects. SurfaceManager.qml copies the results into its MonitorState objects.
//
// Monitor state (plain object, same fields as MonitorState.qml):
//   { name, notch, notchArgs, notchSerial, passive, passiveTop, deck, deckPages, deckArgs,
//     overview, overviewArgs, menu, capture, fullscreen, hero, instant }
// Global state: { active, locked, polkit: monitor|"", pending: [req], previousWindow,
//                 currentWindow, settingsOpen, settingsArgs, serial }
// A request: { op: "open"|"close"|"toggle", surface, args, monitor }
// Every operation returns { monitors: {name: state}, global, effects: [effect] } without
// mutating its input. Effects: { kind: "opened"|"closed"|"refused"|"queued"|"settingsFocus",
// surface, monitor }.

// Surface ids.
var NOTCH_MODES = ["spotlight", "switcher", "today", "session", "polkit", "gallery", "jot",
                   "keys", "keysPeek", "focusPicker"]
var CARD_PREFIX = "card:"
var DRAWERS = ["deck", "overview"]
var OTHER = ["capture", "menu", "settings"]
// Notch modes that do not take the keyboard (keys-jot.md §1: the peek; notch.md §2: hover cards
// are opened with args.hover).
var PASSIVE_MODES = ["keysPeek"]
// Passive kinds and their arbitration order (notch.md §9).
var PASSIVE_KINDS = ["osd", "toast", "event"]
// Toasts queued behind an interactive mode show on close only if younger than this (07 §5).
var TOAST_QUEUE_MAX_AGE = 30000
// Events older than this are dropped (notch.md §7).
var EVENT_MAX_AGE = 4000
// What may still happen while locked: passive OSD only (07 §5).
var LOCKED_ALLOWED_PASSIVE = ["osd"]

function notImplemented(name) { throw new Error("rules." + name + ": not implemented") }

function isNotchMode(surface) { notImplemented("isNotchMode") }
function newMonitor(name) { notImplemented("newMonitor") }
function newGlobal() { notImplemented("newGlobal") }
// Whether the monitor has an interactive surface open (keyboard exclusive, away catcher).
function interactive(m) { notImplemented("interactive") }
// The surface Esc acts on first: "menu", a notch mode, "deck", "overview", "capture" or "".
function top(m) { notImplemented("top") }
function isOpen(m, global, surface) { notImplemented("isOpen") }

function open(monitors, global, req, now) { notImplemented("open") }
function close(monitors, global, req, now) { notImplemented("close") }
function toggle(monitors, global, req, now) { notImplemented("toggle") }
// The Esc ladder (05 §3): close the menu, else ask the top surface's back handler
// (backResult: true when it stepped back internally), else close the top surface.
function back(monitors, global, monitor, backResult, now) { notImplemented("back") }

// Passive content: queue it and arbitrate. → also { id } of the new entry.
function post(monitors, global, kind, payload, priority, monitor, now) { notImplemented("post") }
function dismiss(monitors, global, monitor, id, now) { notImplemented("dismiss") }
// notch.md §9: the entry the notch shows now, or null.
function arbitrate(m, now) { notImplemented("arbitrate") }
// Drop expired events and toasts that waited too long behind an interactive mode.
function expire(m, now) { notImplemented("expire") }

function openMenu(monitors, global, monitor, menu) { notImplemented("openMenu") }
function closeMenu(monitors, global, monitor) { notImplemented("closeMenu") }

// Environment changes.
function addMonitor(monitors, global, name) { notImplemented("addMonitor") }
function removeMonitor(monitors, global, name) { notImplemented("removeMonitor") }
function setActive(monitors, global, name) { notImplemented("setActive") }
function setLocked(monitors, global, locked) { notImplemented("setLocked") }
function setFullscreen(monitors, global, name, fullscreen) { notImplemented("setFullscreen") }
// The settings window reports whether it is focused (settings.md §2 toggle semantics).
function settingsFocused(monitors, global, focused) { notImplemented("settingsFocused") }
