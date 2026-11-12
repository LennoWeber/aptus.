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
// A passive entry: { id, kind: "osd"|"toast"|"event", payload, priority, key, born, waited,
//   replying } — waited: it queued behind a blocking surface (toastStale counts once it
//   unblocks); replying: a toast's inline reply field is open (setReplying).
//   A "critical" toast has priority ≥ 2 (freedesktop urgency); Notifications, Timers and Battery
//   post critical toasts with priority 2.
// Every operation returns { monitors: {name: state}, global, effects: [effect] } without
// mutating its input. Effects: { kind: "opened"|"closed"|"refused"|"queued"|"settingsFocus",
// surface, monitor }, and { kind: "passiveGone", surface: the entry's kind, monitor, id, key } for
// every passive entry that left (dismissed, aged out, its monitor removed).

// Surface ids.
var NOTCH_MODES = ["spotlight", "switcher", "today", "session", "polkit", "gallery", "jot",
                   "keys", "keysPeek", "focusPicker"]
var CARD_PREFIX = "card:"
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
// A pinned card closes after limits.pinnedCardTimeout without the pointer over it (notch.md §4):
// the Notch knows the hover and closes it (notch.js dueEntries), rules.js keeps the limit.
// What may still happen while locked: passive OSD only (07 §5).
var LOCKED_ALLOWED_PASSIVE = ["osd"]

// Invariants.
// States that must never exist. Thrown as "rules invariant: …" (a bug, never user input). Every
// public operation checks its input and finish() checks every result, so a bug is caught at the
// operation that made it and SurfaceManager never applies a broken state.
function invariant(cond, message) { if (!cond) throw new Error("rules invariant: " + message) }
function legalNotch(n) { return n === "rest" || NOTCH_MODES.indexOf(n) >= 0 || isCard(n) }
function checkState(monitors, global) {
    invariant(monitors && typeof monitors === "object", "monitors is not a map")
    invariant(global && typeof global === "object", "global is missing")
    var names = Object.keys(monitors)
    var captured = 0, polkit = []
    for (var i = 0; i < names.length; i++) {
        var m = monitors[names[i]]
        invariant(m && m.name === names[i], "monitor key " + names[i] + " ≠ its name")
        invariant(legalNotch(m.notch), names[i] + ": unknown notch state " + m.notch)
        invariant(Array.isArray(m.deckPages) && m.deckPages.length > 0 && m.deckPages[0] === "main",
                  names[i] + ": the Deck stack must start with main")
        invariant(!(m.overview && (m.deck || m.notch !== "rest")), names[i] + ": Overview open beside another surface")
        invariant(!(m.deck && isInteractiveMode(m.notch)), names[i] + ": Deck and an interactive notch mode both open")
        if (m.capture) captured++
        if (m.notch === "polkit") polkit.push(names[i])
        invariant(!(m.capture && m.notch === "polkit"), names[i] + ": capture beside the polkit prompt")
        invariant(!(m.capture && !(m.capture.args || {}).includeShell
                    && (m.menu || isInteractiveMode(m.notch) || m.deck || m.overview)),
                  names[i] + ": a menu, notch mode, Deck or Overview open under capture (capture.md §7)")
        invariant(!(global.locked && (m.menu || m.capture)), names[i] + ": menu or capture while locked")
        invariant(Array.isArray(m.passive), names[i] + ": passive is not a list")
        var ids = {}, keys = {}
        for (var j = 0; j < m.passive.length; j++) {
            var e = m.passive[j]
            invariant(PASSIVE_KINDS.indexOf(e.kind) >= 0, names[i] + ": unknown passive kind " + e.kind)
            invariant(!ids[e.id], names[i] + ": passive id " + e.id + " twice")
            ids[e.id] = true
            invariant(e.id <= global.passiveSerial, names[i] + ": passive id beyond passiveSerial")
            invariant(!e.replying || e.kind === "toast", names[i] + ": a replying " + e.kind)
            if (e.key) {
                // a key coalesces entries of one kind (post() replaces in place): unique per kind
                invariant(!keys[e.kind + ":" + e.key], names[i] + ": passive " + e.kind + " key " + e.key + " twice")
                keys[e.kind + ":" + e.key] = true
            }
        }
    }
    invariant(captured === 0 || captured === names.length, "capture open on some monitors only")
    invariant(polkit.length <= 1, "polkit open on " + polkit.length + " monitors")
    invariant((global.polkitMonitor === "") === (polkit.length === 0)
              && (polkit.length === 0 || polkit[0] === global.polkitMonitor), "polkitMonitor ≠ the polkit notch")
    invariant(Array.isArray(global.pending), "pending is not a list")
    invariant(global.pending.length === 0 || global.polkitMonitor !== "", "requests queued without polkit")
    for (var k = 0; k < global.pending.length; k++) {
        checkRequest(global.pending[k])
        invariant(global.pending[k].surface !== "polkit", "a polkit request in the queue")
    }
    invariant(!global.settingsFocused || global.settingsOpen, "settings focused but not open")
}
// A request's shape (open/close/toggle).
function checkRequest(req) {
    invariant(req && typeof req.surface === "string" && req.surface !== "", "request without a surface")
}

// Private helpers. c: the working copy of one operation ({ monitors, global, effects }).
function isCard(s) {
    return typeof s === "string" && s.indexOf(CARD_PREFIX) === 0
        && ACTIVITIES.indexOf(s.substr(CARD_PREFIX.length)) >= 0
}
function isInteractiveMode(n) { return n !== "rest" && NOTCH_MODES.indexOf(n) >= 0 && PASSIVE_MODES.indexOf(n) < 0 }
function pinnedCard(m) { return isCard(m.notch) && !!(m.notchArgs && m.notchArgs.pinned) }
// A pinned card is what shows (not covered by an OSD, toast or event): the Notch's outside
// catcher and whole-monitor mask are up only then.
function pinnedShown(m) { return pinnedCard(m) && !!m.passiveTop && m.passiveTop.kind === "card" }
// Toasts queue, OSD and events are dropped (notch.md §9): an interactive notch mode, Overview, Capture.
function blocksPassive(m) { return isInteractiveMode(m.notch) || m.overview || m.capture !== null }
function copyMonitor(m) {
    var o = {}
    for (var k in m) o[k] = m[k]
    o.passive = m.passive.map(function (e) { var c = {}; for (var f in e) c[f] = e[f]; return c })
    o.deckPages = m.deckPages.slice()
    return o
}
// Every operation starts here: its input is checked (finish() checks its output) and copied.
function begin(monitors, global) {
    checkState(monitors, global)
    var c = { monitors: {}, global: {}, effects: [], keyboardBefore: false }
    for (var n in monitors) {
        c.monitors[n] = copyMonitor(monitors[n])
        c.monitors[n].instant = false
        if (monitors[n].keyboard) c.keyboardBefore = true
    }
    for (var k in global) c.global[k] = global[k]
    c.global.pending = (global.pending || []).slice()
    c.global.limits = withDefaults(global.limits)
    return c
}
function effect(c, kind, surface, monitor) { c.effects.push({ kind: kind, surface: surface, monitor: monitor || "" }) }
function goneEffect(c, m, e) { c.effects.push({ kind: "passiveGone", surface: e.kind, monitor: m.name, id: e.id, key: e.key }) }
function finish(c, now) {
    now = nowOr(now)
    var g = c.global, opts = { overFullscreen: g.overFullscreen, limits: g.limits, expired: true }
    var keyboardAfter = false
    for (var n in c.monitors) {
        var m = c.monitors[n]
        if (blocksPassive(m))
            for (var i = 0; i < m.passive.length; i++) if (m.passive[i].kind === "toast") m.passive[i].waited = true
        var kept = expire(m, now, g.limits).passive, keptIds = {}
        for (var j = 0; j < kept.length; j++) keptIds[kept[j].id] = true
        for (var k = 0; k < m.passive.length; k++) if (!keptIds[m.passive[k].id]) goneEffect(c, m, m.passive[k])
        m.passive = kept
        m.interactive = interactive(m)
        m.passiveTop = arbitrate(m, now, opts)
        m.keyboard = keyboard(m)
        m.top = top(m)
        if (m.keyboard) keyboardAfter = true
    }
    // 07 §5: the window that had the keyboard before the shell took it (paste-back, focus replay)
    if (!c.keyboardBefore && keyboardAfter) g.previousWindow = g.currentWindow
    checkState(c.monitors, g)
    return { monitors: c.monitors, global: g, effects: c.effects }
}
function closeNotchOn(c, m) {
    var old = m.notch
    if (old === "rest") return
    m.notch = "rest"; m.notchArgs = {}; m.hero = ""
    effect(c, "closed", old, m.name)
    if (old === "polkit") { c.global.polkitMonitor = ""; flushPending(c) }
}
function closeDeckOn(c, m) { m.deck = false; m.deckPages = ["main"]; m.deckArgs = {}; effect(c, "closed", "deck", m.name) }
function closeOverviewOn(c, m) { m.overview = false; m.overviewArgs = {}; effect(c, "closed", "overview", m.name) }
function closeMenuOn(c, m) { if (m.menu) { m.menu = null; effect(c, "closed", "menu", m.name) } }
function closeCapture(c) {
    var any = false
    for (var n in c.monitors) if (c.monitors[n].capture) { c.monitors[n].capture = null; any = true }
    if (any) effect(c, "closed", "capture", c.global.activeMonitor)
}
function flushPending(c) {
    var q = c.global.pending
    c.global.pending = []
    for (var i = 0; i < q.length; i++) {
        if (q[i].op === "toggle") doToggle(c, q[i]); else doOpen(c, q[i])
    }
}
function nowOr(now) { return now === undefined ? Date.now() : now }
// The monitor an operation acts on: the polkit prompt's own (one prompt: a new request replaces
// it where it is, focus may have moved), else the requested one, else the active monitor.
function monitorOf(c, req) {
    if (req.surface === "polkit" && c.global.polkitMonitor) return c.global.polkitMonitor
    return req.monitor || c.global.activeMonitor
}
function doOpen(c, req) {
    var s = req.surface, args = req.args || {}, g = c.global, name = monitorOf(c, req)
    if (g.locked) return effect(c, "refused", s, name)
    if (g.polkitMonitor && s !== "polkit") {
        g.pending.push({ op: req.op === "toggle" ? "toggle" : "open", surface: s, args: args, monitor: req.monitor || "" })
        return effect(c, "queued", s, name)
    }
    if (s === "settings") {
        g.settingsArgs = args
        if (g.settingsOpen) return effect(c, "settingsFocus", "settings", "")
        g.settingsOpen = true
        return effect(c, "opened", "settings", "")
    }
    var m = c.monitors[name]
    if (!m) return effect(c, "refused", s, name)
    if (s === "capture") {
        // open shell surfaces close first unless they belong in the image (capture.md §7); then
        // every monitor freezes once and shows the overlay (§3)
        for (var n in c.monitors) {
            var cm = c.monitors[n]
            if (!args.includeShell) {
                closeMenuOn(c, cm)
                if (isInteractiveMode(cm.notch)) closeNotchOn(c, cm)
                if (cm.deck) closeDeckOn(c, cm)
                if (cm.overview) closeOverviewOn(c, cm)
            }
            cm.capture = { mode: args.mode || "region", args: args }
            cm.hero = "capture"
        }
        return effect(c, "opened", "capture", name)
    }
    if (m.capture && s !== "polkit") return effect(c, "refused", s, name)
    closeMenuOn(c, m)
    if (s === "overview") {
        closeNotchOn(c, m)
        if (m.deck) closeDeckOn(c, m)
        m.overview = true; m.overviewArgs = args; m.hero = "overview"
        return effect(c, "opened", "overview", name)
    }
    if (s === "deck") {
        if (isInteractiveMode(m.notch) || pinnedCard(m)) closeNotchOn(c, m)
        if (m.overview) closeOverviewOn(c, m)
        if (!m.deck) { m.deck = true; m.deckPages = args.page ? ["main", args.page] : ["main"] }
        else if (args.page) m.deckPages = ["main", args.page]
        m.deckArgs = args; m.hero = "deck"
        return effect(c, "opened", "deck", name)
    }
    if (!isNotchMode(s)) return effect(c, "refused", s, name)
    if (isCard(s) || s === "keysPeek") {
        if (blocksPassive(m)) return effect(c, "refused", s, name)
        if (isCard(s) && args.pinned && m.deck) closeDeckOn(c, m)
    } else {
        if (m.deck) closeDeckOn(c, m)
        if (m.overview) closeOverviewOn(c, m)
    }
    if (s === "polkit") { closeCapture(c); g.polkitMonitor = name }
    if (m.notch !== s && m.notch !== "rest") effect(c, "closed", m.notch, name)   // morph A → B
    m.notch = s; m.notchArgs = args; m.notchSerial = m.notchSerial + 1; m.hero = s
    effect(c, "opened", s, name)
}
function doClose(c, req) {
    var s = req.surface, g = c.global
    if (s === "settings") {
        if (g.settingsOpen) { g.settingsOpen = false; g.settingsFocused = false; effect(c, "closed", "settings", "") }
        return
    }
    if (s === "capture") return closeCapture(c)
    var name = monitorOf(c, req)
    var m = c.monitors[name]
    if (!m) return
    if (s === "menu") return closeMenuOn(c, m)
    if (s === "deck") { if (m.deck) closeDeckOn(c, m); return }
    if (s === "overview") { if (m.overview) closeOverviewOn(c, m); return }
    if (isNotchMode(s) && m.notch === s) { closeMenuOn(c, m); closeNotchOn(c, m) }
}
function doToggle(c, req) {
    var s = req.surface, g = c.global
    if (s === "settings") {
        if (!g.settingsOpen) return doOpen(c, req)
        if (!g.settingsFocused) return effect(c, "settingsFocus", "settings", "")
        return doClose(c, req)
    }
    var m = c.monitors[monitorOf(c, req)]
    if (m && isOpen(m, g, s)) doClose(c, req); else doOpen(c, { op: "toggle", surface: s, args: req.args, monitor: req.monitor })
}
function findEntry(c, monitor, id) {
    for (var n in c.monitors) {
        if (monitor && n !== monitor) continue
        var p = c.monitors[n].passive
        for (var i = 0; i < p.length; i++) if (p[i].id === id) return { m: c.monitors[n], i: i }
    }
    return null
}

function isNotchMode(surface) { return NOTCH_MODES.indexOf(surface) >= 0 || isCard(surface) }
function newMonitor(name) {
    return { name: name, notch: "rest", notchArgs: {}, notchSerial: 0, passive: [],
             passiveTop: { kind: "rest", entry: null }, deck: false, deckPages: ["main"], deckArgs: {},
             overview: false, overviewArgs: {}, menu: null, capture: null, fullscreen: false,
             hero: "", instant: false, interactive: false, keyboard: false, top: "" }
}
// limits with DEFAULT_LIMITS for every missing or unset value.
function withDefaults(limits) {
    var l = {}
    for (var k in DEFAULT_LIMITS) l[k] = limits && limits[k] !== undefined && limits[k] !== null ? limits[k] : DEFAULT_LIMITS[k]
    return l
}
function newGlobal(limits) {
    var l = withDefaults(limits)
    return { activeMonitor: "", locked: false, polkitMonitor: "", pending: [], previousWindow: "",
             currentWindow: "", settingsOpen: false, settingsArgs: {}, settingsFocused: false,
             passiveSerial: 0, limits: l, overFullscreen: "critical" }
}
// Whether the monitor has an interactive surface open (away catcher). Includes menus; toasts
// queue only behind an interactive notch mode, Overview and Capture (blocksPassive).
function interactive(m) {
    return isInteractiveMode(m.notch) || m.deck || m.overview || m.capture !== null || m.menu !== null
}
// Whether the shell layer takes the keyboard: interactive, a card opened by click, or a toast
// with its reply field open (notch.md §6). A pinned card only while it shows: under an OSD, toast
// or event the keyboard stays with the app.
function keyboard(m) {
    return interactive(m) || pinnedShown(m)
        || (!!m.passiveTop && m.passiveTop.kind === "toast" && !!m.passiveTop.entry.replying)
}
// The surface Esc acts on first: "menu", a notch mode, "deck", "overview", "capture" or "".
function top(m) {
    if (m.menu) return "menu"
    if (m.capture) return "capture"
    if (isInteractiveMode(m.notch) || pinnedCard(m)) return m.notch
    if (m.deck) return "deck"
    if (m.overview) return "overview"
    return ""
}
function isOpen(m, global, surface) {
    if (surface === "settings") return !!global.settingsOpen
    if (!m) return false
    if (surface === "deck") return m.deck
    if (surface === "overview") return m.overview
    if (surface === "capture") return m.capture !== null
    if (surface === "menu") return m.menu !== null
    return m.notch === surface
}

function open(monitors, global, req, now) { checkRequest(req); var c = begin(monitors, global); doOpen(c, req); return finish(c, now) }
function close(monitors, global, req, now) { checkRequest(req); var c = begin(monitors, global); doClose(c, req); return finish(c, now) }
function toggle(monitors, global, req, now) { checkRequest(req); var c = begin(monitors, global); doToggle(c, req); return finish(c, now) }
// The Esc ladder (05 §3): close the menu, else pop a Deck page, else ask the top surface's back
// handler (backResult: true when it stepped back internally), else close the top surface.
// open("deck", { page }) pushes a page; opening the Deck when it is open with a page replaces the
// stack with ["main", page].
function back(monitors, global, monitor, backResult, now) {
    var c = begin(monitors, global), m = c.monitors[monitorOf(c, { monitor: monitor })]
    if (m) {
        var t = top(m)
        if (t === "menu") closeMenuOn(c, m)
        else if (t === "deck" && m.deckPages.length > 1) m.deckPages = m.deckPages.slice(0, -1)
        else if (backResult) {}
        else if (t) doClose(c, { surface: t, monitor: m.name })
    }
    return finish(c, now)
}

// Passive content: queue it and arbitrate. A non-empty key replaces the entry with that key in
// place (keeps its id and position, resets born). → also { id } of the entry.
function post(monitors, global, kind, payload, priority, monitor, key, now) {
    now = nowOr(now)
    var c = begin(monitors, global), g = c.global, name = monitorOf(c, { monitor: monitor }), m = c.monitors[name]
    var id = 0
    var refused = !m || PASSIVE_KINDS.indexOf(kind) < 0
        || (g.locked && LOCKED_ALLOWED_PASSIVE.indexOf(kind) < 0)
        || (kind !== "toast" && blocksPassive(m))    // OSD suppressed, events dropped (not by the Deck, 05 §2)
    if (refused) effect(c, "refused", kind, name)
    else {
        if (key) for (var i = 0; i < m.passive.length; i++) {
            var e = m.passive[i]
            if (e.kind === kind && e.key === key) {
                e.payload = payload; e.priority = priority || 0; e.born = now; id = e.id
                break
            }
        }
        if (!id) {
            g.passiveSerial = g.passiveSerial + 1
            id = g.passiveSerial
            m.passive.push({ id: id, kind: kind, key: key || "", payload: payload, priority: priority || 0, born: now,
                             waited: false, replying: false })
        }
    }
    var r = finish(c, now)
    r.id = id
    return r
}
// Change an entry's payload in place (stack toast, OSD value).
function update(monitors, global, monitor, id, payload, now) {
    var c = begin(monitors, global), f = findEntry(c, monitor, id)
    if (f) f.m.passive[f.i].payload = payload
    return finish(c, now)
}
// A toast's inline reply field opened or closed (notch.md §6): while it is open the toast stays
// above an OSD and the shell layer takes the keyboard. Other kinds are left alone.
function setReplying(monitors, global, monitor, id, on, now) {
    var c = begin(monitors, global), f = findEntry(c, monitor, id)
    if (f && f.m.passive[f.i].kind === "toast") f.m.passive[f.i].replying = !!on
    return finish(c, now)
}
function dismiss(monitors, global, monitor, id, now) {
    var c = begin(monitors, global), f = findEntry(c, monitor, id)
    if (f) goneEffect(c, f.m, f.m.passive.splice(f.i, 1)[0])
    return finish(c, now)
}
// notch.md §9 → { kind: "osd" | "toast" | "event" | "card" | "rest" | "hidden", entry }.
// opts: { overFullscreen: "critical" | "none" | "all" (notch.overFullscreen), limits }.
// Order: OSD (newest; also while the Deck is open, 05 §2) > toast (highest priority, then
// FIFO) > event > card > rest; a toast whose reply field is open is not covered by an OSD (the
// OSD entry still expires on time). Under an interactive mode: OSD suppressed, events dropped, toasts
// queued (rest is reported). Under a fullscreen window: "hidden" except OSD and what
// overFullscreen allows (critical: priority ≥ 2). The recording dot is the Notch's own drawing.
function arbitrate(m, now, opts) {
    opts = opts || {}
    if (blocksPassive(m)) return { kind: "rest", entry: null }
    var list = opts.expired ? m.passive : expire(m, now, opts.limits).passive
    var hiding = m.fullscreen && opts.overFullscreen !== "all"
    function allowed(e) {
        if (!hiding) return true
        return e.kind === "osd" || (opts.overFullscreen === "critical" && e.kind === "toast" && e.priority >= 2)
    }
    var osd = null, toast = null, ev = null, replying = null
    for (var i = 0; i < list.length; i++) {
        var e = list[i]
        if (!allowed(e)) continue
        if (e.kind === "osd" && (!osd || e.born >= osd.born)) osd = e      // the newest OSD
        else if (e.kind === "toast" && (!toast || e.priority > toast.priority)) toast = e   // FIFO within a priority
        else if (e.kind === "event" && !ev) ev = e
        if (e.replying && !replying) replying = e
    }
    if (osd) return replying ? { kind: "toast", entry: replying } : { kind: "osd", entry: osd }
    if (toast) return { kind: "toast", entry: toast }
    if (ev) return { kind: "event", entry: ev }
    if (hiding) return { kind: "hidden", entry: null }
    if (isCard(m.notch)) return { kind: "card", entry: m.notch.substr(CARD_PREFIX.length) }
    return { kind: "rest", entry: null }
}
// Drop events older than limits.eventMaxAge (unless shown) and waited toasts older than
// limits.toastStale once nothing blocks them.
function expire(m, now, limits) {
    limits = limits || DEFAULT_LIMITS
    var blocking = blocksPassive(m)
    var shownId = m.passiveTop && m.passiveTop.entry && m.passiveTop.entry.id
    var out = {}
    for (var k in m) out[k] = m[k]
    out.passive = []
    for (var i = 0; i < m.passive.length; i++) {
        var e = m.passive[i]
        if (e.kind === "event" && e.id !== shownId && now - e.born > limits.eventMaxAge) continue
        if (e.kind === "toast" && e.waited && !blocking) {
            if (now - e.born > limits.toastStale) continue          // Today only (07 §5)
            var c = {}; for (var f in e) c[f] = e[f]; c.waited = false; e = c
        }
        out.passive.push(e)
    }
    return out
}

function openMenu(monitors, global, monitor, menu, now) {
    var c = begin(monitors, global), name = monitorOf(c, { monitor: monitor }), m = c.monitors[name]
    if (!m || c.global.locked || (c.global.polkitMonitor && c.global.polkitMonitor !== name) || m.capture)
        effect(c, "refused", "menu", name)
    else { m.menu = menu; effect(c, "opened", "menu", name) }
    return finish(c, now)
}
function closeMenu(monitors, global, monitor, now) {
    var c = begin(monitors, global), m = c.monitors[monitorOf(c, { monitor: monitor })]
    if (m) closeMenuOn(c, m)
    return finish(c, now)
}

// Environment changes.
function addMonitor(monitors, global, name, now) {
    var c = begin(monitors, global)
    // the new monitor has no frozen frame: the selection is cancelled (07 §5, capture.md §7)
    if (!c.monitors[name]) { closeCapture(c); c.monitors[name] = newMonitor(name) }
    if (!c.global.activeMonitor) c.global.activeMonitor = name
    return finish(c, now)
}
function removeMonitor(monitors, global, name, now) {
    var c = begin(monitors, global), m = c.monitors[name], g = c.global
    if (!m) return finish(c, now)
    var hadPolkit = g.polkitMonitor === name, polkitArgs = m.notchArgs
    var opened = ["menu", "capture", m.notch !== "rest" ? m.notch : "", m.deck ? "deck" : "", m.overview ? "overview" : ""]
    for (var i = 0; i < opened.length; i++)
        if (opened[i] && (opened[i] !== "menu" || m.menu) && (opened[i] !== "capture" || m.capture))
            effect(c, "closed", opened[i], name)
    for (var j = 0; j < m.passive.length; j++) goneEffect(c, m, m.passive[j])
    delete c.monitors[name]
    if (g.activeMonitor === name) { var rest = Object.keys(c.monitors); g.activeMonitor = rest.length ? rest[0] : "" }
    if (hadPolkit) {
        g.polkitMonitor = ""
        // the prompt moves to the active monitor without animation
        if (g.activeMonitor) doOpen(c, { surface: "polkit", args: polkitArgs, monitor: g.activeMonitor })
        if (g.polkitMonitor) c.monitors[g.polkitMonitor].instant = true
        // not shown again (no monitor left, or locked): the request is cancelled and nothing is
        // left to replay the queue onto (07 §5)
        else g.pending = []
    }
    return finish(c, now)
}
function setActive(monitors, global, name, now) {
    var c = begin(monitors, global), g = c.global
    if (g.activeMonitor !== name && c.monitors[name]) {
        var old = c.monitors[g.activeMonitor]
        // the Spotlight rule (07 §5): a notch mode on the old monitor closes, a card too (cards
        // only on the active monitor, 05 §7); passive content (toasts, OSD, events) stays
        if (old && old.notch !== "rest" && old.notch !== "polkit") { closeMenuOn(c, old); closeNotchOn(c, old) }
        g.activeMonitor = name
    }
    return finish(c, now)
}
function setLocked(monitors, global, locked, now) {
    var c = begin(monitors, global)
    c.global.locked = !!locked
    if (locked) {
        for (var n in c.monitors) closeMenuOn(c, c.monitors[n])
        closeCapture(c)
    }
    return finish(c, now)
}
function setFullscreen(monitors, global, name, fullscreen, now) {
    var c = begin(monitors, global)
    if (c.monitors[name]) c.monitors[name].fullscreen = !!fullscreen
    return finish(c, now)
}
// The settings window reports whether it is focused (settings.md §2 toggle semantics).
function setSettingsFocused(monitors, global, focused, now) {
    var c = begin(monitors, global)
    c.global.settingsFocused = !!focused
    return finish(c, now)
}
// When the next entry ages out without an operation (ms since the epoch, 0 = never): the oldest
// event that is not shown (07 §5). SurfaceManager arms one timer for it instead of polling. Waited
// toasts need none: they only go stale once nothing blocks them, and unblocking is an operation.
function nextDeadline(monitors, global) {
    var limits = withDefaults(global.limits), next = 0
    for (var n in monitors) {
        var m = monitors[n], shownId = m.passiveTop && m.passiveTop.entry && m.passiveTop.entry.id
        for (var i = 0; i < m.passive.length; i++) {
            var e = m.passive[i]
            if (e.kind !== "event" || e.id === shownId) continue
            var at = e.born + limits.eventMaxAge + 1
            if (!next || at < next) next = at
        }
    }
    return next
}
// Re-run expiry and arbitration without an operation (SurfaceManager's timer: events age out).
function tick(monitors, global, now) { return finish(begin(monitors, global), now) }
