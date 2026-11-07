.pragma library
// The surface transition rules of 07-architecture §5 and 05-interaction §2/§3, as pure functions
// over plain objects. SurfaceManager.qml copies the results into its MonitorState objects.
//
// Monitor state (plain object, same fields as MonitorState.qml):
//   { name, notch, notchArgs, notchSerial, passive, passiveTop, deck, deckPages, deckArgs,
//     overview, overviewArgs, menu, capture, fullscreen, hero, instant, interactive, keyboard, top }
// Global state, same names as SurfaceManager.qml: { activeMonitor, locked, polkitMonitor,
//   pending: [req], previousWindow, currentWindow, settingsOpen, settingsArgs, settingsFocused,
//   passiveSerial, limits: { toastStale, eventMaxAge, pinnedCardTimeout }, overFullscreen }
// A request: { op: "open"|"close"|"toggle", surface, args, monitor }
// A passive entry: { id, kind: "osd"|"toast"|"event", payload, priority, key, born, shown,
//   waited } — waited: it queued behind a blocking surface (toastStale counts once it unblocks).
//   A "critical" toast has priority ≥ 2 (freedesktop urgency); Notifications, Timers and Battery
//   post critical toasts with priority 2.
// Every operation returns { monitors: {name: state}, global, effects: [effect] } without
// mutating its input. Effects: { kind: "opened"|"closed"|"refused"|"queued"|"settingsFocus",
// surface, monitor }.

// Surface ids.
var NOTCH_MODES = ["spotlight", "switcher", "today", "session", "polkit", "gallery", "jot",
                   "keys", "keysPeek", "focusPicker"]
var CARD_PREFIX = "card:"
var DRAWERS = ["deck", "overview"]
// Menus are not surfaces here: they go through openMenu/closeMenu.
var OTHER = ["capture", "settings"]
// Notch states that are not interactive (no away catcher, toasts do not queue, 07 §5): the peek
// and every card. A card opened by click (args.pinned) still takes the keyboard.
var PASSIVE_MODES = ["keysPeek"]
// Activity ids a card can show (notch.md §5).
var ACTIVITIES = ["recording", "timer", "meeting", "focus", "media", "progress"]
// Passive kinds and their arbitration order (notch.md §9).
var PASSIVE_KINDS = ["osd", "toast", "event"]
// Defaults for global.limits (SurfaceManager passes the token values: toast.staleMs,
// event.maxAgeMs, notch.pinnedCardTimeoutMs).
var DEFAULT_LIMITS = { toastStale: 30000, eventMaxAge: 4000, pinnedCardTimeout: 8000 }
// What may still happen while locked: passive OSD only (07 §5).
var LOCKED_ALLOWED_PASSIVE = ["osd"]

function notImplemented(name) { throw new Error("rules." + name + ": not implemented") }

// Private helpers. c: the working copy of one operation ({ monitors, global, effects }).
function isCard(s) { notImplemented("isCard") }
function isInteractiveMode(n) { notImplemented("isInteractiveMode") }
function pinnedCard(m) { notImplemented("pinnedCard") }
// Toasts queue, OSD and events are dropped (notch.md §9): an interactive notch mode, Overview, Capture.
function blocksPassive(m) { notImplemented("blocksPassive") }
function copyMonitor(m) { notImplemented("copyMonitor") }
function begin(monitors, global) { notImplemented("begin") }
function effect(c, kind, surface, monitor) { notImplemented("effect") }
function finish(c, now) { notImplemented("finish") }
function closeNotchOn(c, m) { notImplemented("closeNotchOn") }
function closeDeckOn(c, m) { notImplemented("closeDeckOn") }
function closeOverviewOn(c, m) { notImplemented("closeOverviewOn") }
function closeMenuOn(c, m) { notImplemented("closeMenuOn") }
function closeCapture(c) { notImplemented("closeCapture") }
function flushPending(c) { notImplemented("flushPending") }
function nowOr(now) { notImplemented("nowOr") }
function monitorOf(c, req) { notImplemented("monitorOf") }
function doOpen(c, req) { notImplemented("doOpen") }
function doClose(c, req) { notImplemented("doClose") }
function doToggle(c, req) { notImplemented("doToggle") }
function findEntry(c, monitor, id) { notImplemented("findEntry") }

function isNotchMode(surface) { notImplemented("isNotchMode") }
function newMonitor(name) { notImplemented("newMonitor") }
function newGlobal(limits) { notImplemented("newGlobal") }
// Whether the monitor has an interactive surface open (away catcher). Includes menus; toasts
// queue only behind an interactive notch mode, Overview and Capture (blocksPassive).
function interactive(m) { notImplemented("interactive") }
// Whether the shell layer takes the keyboard: interactive, or a card opened by click.
function keyboard(m) { notImplemented("keyboard") }
// The surface Esc acts on first: "menu", a notch mode, "deck", "overview", "capture" or "".
function top(m) { notImplemented("top") }
function isOpen(m, global, surface) { notImplemented("isOpen") }

function open(monitors, global, req, now) { notImplemented("open") }
function close(monitors, global, req, now) { notImplemented("close") }
function toggle(monitors, global, req, now) { notImplemented("toggle") }
// The Esc ladder (05 §3): close the menu, else pop a Deck page, else ask the top surface's back
// handler (backResult: true when it stepped back internally), else close the top surface.
// open("deck", { page }) pushes a page; opening the Deck when it is open with a page replaces the
// stack with ["main", page].
function back(monitors, global, monitor, backResult, now) { notImplemented("back") }

// Passive content: queue it and arbitrate. A non-empty key replaces the entry with that key in
// place (keeps its id and position, resets born). → also { id } of the entry.
function post(monitors, global, kind, payload, priority, monitor, key, now) { notImplemented("post") }
// Change an entry's payload in place (stack toast, OSD value).
function update(monitors, global, monitor, id, payload, now) { notImplemented("update") }
function dismiss(monitors, global, monitor, id, now) { notImplemented("dismiss") }
// notch.md §9 → { kind: "osd" | "toast" | "event" | "card" | "rest" | "hidden", entry }.
// opts: { overFullscreen: "critical" | "none" | "all" (notch.overFullscreen), limits }.
// Order: OSD (newest; also while the Deck is open, 05 §2) > toast (highest priority, then
// FIFO) > event > card > rest. Under an interactive mode: OSD suppressed, events dropped, toasts
// queued (rest is reported). Under a fullscreen window: "hidden" except OSD and what
// overFullscreen allows (critical: priority ≥ 2). The recording dot is the Notch's own drawing.
function arbitrate(m, now, opts) { notImplemented("arbitrate") }
// Drop events older than limits.eventMaxAge (unless shown) and waited toasts older than
// limits.toastStale once nothing blocks them.
function expire(m, now, limits) { notImplemented("expire") }

function openMenu(monitors, global, monitor, menu, now) { notImplemented("openMenu") }
function closeMenu(monitors, global, monitor, now) { notImplemented("closeMenu") }

// Environment changes.
function addMonitor(monitors, global, name, now) { notImplemented("addMonitor") }
function removeMonitor(monitors, global, name, now) { notImplemented("removeMonitor") }
function setActive(monitors, global, name, now) { notImplemented("setActive") }
function setLocked(monitors, global, locked, now) { notImplemented("setLocked") }
function setFullscreen(monitors, global, name, fullscreen, now) { notImplemented("setFullscreen") }
// The settings window reports whether it is focused (settings.md §2 toggle semantics).
function setSettingsFocused(monitors, global, focused, now) { notImplemented("setSettingsFocused") }
// Re-run expiry and arbitration without an operation (SurfaceManager's timer: events age out).
function tick(monitors, global, now) { notImplemented("tick") }
