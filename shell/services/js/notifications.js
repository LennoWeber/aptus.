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
// The largest image file a notification may have copied into the cache (today.md §6), bytes.
var IMAGE_MAX_BYTES = 8 * 1024 * 1024
// The held summary's wording per hold reason (05 §8).
var HELD_WHILE = { focus: "while you were focused", dnd: "during Do not disturb", fullscreen: "while in fullscreen" }
// Tags the body keeps (notch.md §6: bold, italic, links).
var KEEP_TAGS = ["b", "i", "a"]

// A record from the plain fields of a notification (the QML side reads them off the object).
function makeRecord(src, now) {
    invariant(src && typeof src === "object", "no source")
    invariant(isFinite(now), "no time")
    var actions = [], hasDefault = false
    var list = src.actions || []
    for (var i = 0; i < list.length; i++) {
        var a = list[i]
        if (!a) continue
        var id = String(a.id === undefined ? "" : a.id)
        if (id === "default") { hasDefault = true; continue }
        if (id === "inline-reply") continue
        actions.push({ id: id, text: String(a.text || id) })
    }
    var u = Number(src.urgency)
    return {
        id: Number(src.id) || 0,
        appName: String(src.appName || "") || FALLBACK_APP,
        appIcon: String(src.appIcon || ""),
        desktopEntry: String(src.desktopEntry || ""),
        summary: String(src.summary || ""),
        body: reduceMarkup(String(src.body || "")),
        image: String(src.image || ""),
        urgency: u === LOW || u === CRITICAL ? u : NORMAL,
        actions: actions,
        hasDefault: hasDefault,
        resident: !!src.resident,
        reply: !!src.hasInlineReply,
        progress: progressOf(src.hints),
        time: now,
        read: false,
        live: !!src.live,
        held: ""
    }
}
// The policy decision for a record (05 §8).
function decide(record, ctx) {
    checkRecord(record)
    checkContext(ctx)
    var d = _decide(record, ctx)
    checkDecision(record, d)
    return d
}
function _decide(record, ctx) {
    var allow = isAllowlisted(record, ctx.allowlist)
    if (record.urgency !== CRITICAL && isMuted(record, ctx.muted, ctx.now))
        return { show: "today", priority: 0, reason: "muted" }
    if (record.progress >= 0 && record.progress < 100)
        return { show: "progress", priority: record.urgency === CRITICAL ? CRITICAL_PRIORITY : 0, reason: "" }
    if (record.urgency === CRITICAL)
        return { show: "toast", priority: CRITICAL_PRIORITY, reason: "" }
    if (record.urgency === LOW) {
        if (ctx.focus) return { show: "held", priority: 0, reason: "focus" }
        return { show: "today", priority: 0, reason: "low" }
    }
    if (!allow && ctx.focus) return { show: "held", priority: 0, reason: "focus" }
    if (!allow && ctx.dnd) return { show: "held", priority: 0, reason: "dnd" }
    if (ctx.fullscreen && ctx.overFullscreen !== "all") return { show: "held", priority: 0, reason: "fullscreen" }
    return { show: "toast", priority: 0, reason: "" }
}
// The app is on notifications.allowlist (by app name or desktop entry, case-insensitive).
function isAllowlisted(record, allowlist) {
    invariant(!allowlist || Array.isArray(allowlist), "allowlist is not a list")
    var list = allowlist || []
    var a = _lower(record.appName), d = _lower(record.desktopEntry)
    for (var i = 0; i < list.length; i++) {
        var x = _lower(list[i])
        if (x !== "" && (x === a || x === d)) return true
    }
    return false
}
// The app is muted at `now`.
function isMuted(record, muted, now) {
    invariant(!muted || typeof muted === "object", "muted is not a map")
    var until = muted ? muted[record.appName] : undefined
    return until !== undefined && until > now
}
// Toast timeout in ms (notch.md §6; 0 = until dismissed). setting: notifications.timeout
// ("auto" | seconds); timing: Tokens.surfaces.toast.
function toastTimeout(record, setting, timing) {
    checkRecord(record)
    checkTiming(timing)
    invariant(setting === "auto" || Number(setting) >= 0, "toast timeout setting " + setting)
    if (record.urgency === CRITICAL) return 0
    var extra = record.actions.length > 0 || record.reply ? timing.actionsExtraMs : 0
    if (setting !== "auto" && Number(setting) > 0) return Number(setting) * 1000 + extra
    var chars = (record.summary + plainText(record.body)).length
    var t = Math.min(timing.maxTimeoutMs, Math.max(timing.minTimeoutMs, timing.baseTimeoutMs + timing.perCharMs * chars))
    return t + extra
}
// The toast payload of a record.
function toastPayload(record, timeout, maxActions) {
    checkRecord(record)
    invariant(timeout >= 0 && maxActions >= 0, "toast timeout " + timeout + ", max actions " + maxActions)
    var icon = record.appIcon || record.desktopEntry
    return {
        nid: record.id, appName: record.appName, appIcon: icon, summary: record.summary,
        body: record.body, image: record.image, critical: record.urgency === CRITICAL,
        actions: record.actions.slice(0, maxActions), hasDefault: record.hasDefault,
        resident: record.resident, reply: record.reply, timeout: timeout, time: record.time,
        stack: null, opens: "", glyph: icon ? "" : FALLBACK_GLYPH
    }
}
// The stack after an arrival: { stack, joins: bool } (joins: the arrival updates the stack toast
// instead of posting its own).
function stackStep(stack, record, passiveId, monitor, now, windowMs) {
    checkRecord(record)
    if (stack) checkStack(stack)
    invariant(passiveId >= 0 && windowMs >= 0, "stack id " + passiveId + ", window " + windowMs)
    var icon = record.appIcon || record.desktopEntry
    if (stack && stack.passiveId > 0 && stack.monitor === monitor && now - stack.last <= windowMs) {
        var icons = stack.icons.slice(), apps = stack.apps.slice()
        if (apps.indexOf(record.appName) < 0) { apps.unshift(record.appName); icons.unshift(icon) }
        return { stack: { passiveId: stack.passiveId, monitor: monitor, count: stack.count + 1,
                          icons: icons.slice(0, 3), apps: apps, last: now }, joins: true }
    }
    return { stack: { passiveId: passiveId, monitor: monitor, count: 1, icons: [icon], apps: [record.appName],
                      last: now }, joins: false }
}
// The payload of the stack toast with its newest record.
function stackPayload(stack, newest, timeout) {
    checkStack(stack)
    invariant(stack.count >= 2 && stack.passiveId > 0, "a stack toast for " + stack.count + " notification(s)")
    checkRecord(newest)
    var p = toastPayload(newest, timeout, 0)
    p.nid = 0
    p.summary = stack.count + " notifications"
    p.body = newest.summary
    p.image = ""
    p.hasDefault = false
    p.resident = false
    p.reply = false
    p.stack = { count: stack.count, icons: stack.icons.slice(), apps: stack.apps.slice() }
    p.opens = "today"
    return p
}
// The summary toast for `count` held notifications.
function heldPayload(count, reason, timeout) {
    invariant(count >= 1, "held summary of " + count)
    invariant(isHoldReason(reason), "unknown hold reason " + reason)
    var p = systemToast(count + (count === 1 ? " notification " : " notifications ") + (HELD_WHILE[reason] || ""),
                        "", FALLBACK_GLYPH, false, timeout)
    p.opens = "today"
    return p
}
// A toast the shell raises itself (no notification behind it: battery, urgent workspace): a
// toast payload with nid 0, the glyph instead of the app icon, no actions.
function systemToast(title, body, glyph, critical, timeout) {
    invariant(typeof title === "string" && title !== "", "system toast without a title")
    invariant(critical || timeout > 0, "system toast without a timeout")
    return { nid: 0, appName: "", appIcon: "", summary: String(title), body: String(body || ""), image: "",
             critical: !!critical, actions: [], hasDefault: false, resident: false, reply: false,
             timeout: critical ? 0 : timeout, time: 0, stack: null, opens: "", glyph: glyph || FALLBACK_GLYPH }
}
// Body markup reduced to <b>, <i> and <a href>; everything else escaped or dropped.
function reduceMarkup(body) {
    invariant(typeof body === "string", "body is not a string")
    var out = "", open = [], last = 0, m
    var re = /<(\/?)([a-zA-Z][a-zA-Z0-9]*)([^<>]*)>/g
    while ((m = re.exec(body)) !== null) {
        out += _escape(body.substring(last, m.index)).replace(/\n/g, "<br>")
        last = re.lastIndex
        var closing = m[1] === "/", tag = m[2].toLowerCase()
        if (tag === "br" && !closing) { out += "<br>"; continue }
        if (KEEP_TAGS.indexOf(tag) < 0) continue
        if (closing) {
            var at = open.lastIndexOf(tag)
            if (at < 0) continue
            while (open.length > at) out += "</" + open.pop() + ">"
            continue
        }
        if (tag === "a") {
            var h = /href\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/i.exec(m[3])
            var href = h ? (h[1] !== undefined ? h[1] : h[2] !== undefined ? h[2] : h[3]) : ""
            if (!/^(https?:|mailto:)/i.test(href)) { open.push("span"); out += "<span>"; continue }
            out += '<a href="' + href.replace(/&(?!amp;)/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;") + '">'
        } else out += "<" + tag + ">"
        open.push(tag)
    }
    out += _escape(body.substring(last)).replace(/\n/g, "<br>")
    while (open.length) out += "</" + open.pop() + ">"
    return out
}
// The visible text of reduced markup (for the timeout's character count).
function plainText(markup) {
    invariant(typeof markup === "string", "markup is not a string")
    return String(markup).replace(/<br>/g, "\n").replace(/<[^>]*>/g, "")
        .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&")
}
// The progress hint (`value` 0–100) or -1.
function progressOf(hints) {
    if (!hints || hints.value === undefined || hints.value === null) return -1
    var v = Number(hints.value)
    if (!isFinite(v)) return -1
    return Math.max(0, Math.min(100, Math.round(v)))
}
// History operations (new arrays; history newest first).
function addToHistory(history, record, max, days, now) {
    checkHistory(history)
    checkRecord(record)
    invariant(max >= 1 && days >= 1, "history limits " + max + "/" + days)
    var out = [record]
    for (var i = 0; i < history.length; i++) if (history[i].id !== record.id) out.push(history[i])
    return trimHistory(out, max, days, now)
}
function trimHistory(history, max, days, now) {
    checkHistory(history)
    invariant(max >= 1 && days >= 1, "history limits " + max + "/" + days)
    var oldest = now - days * 86400000
    var out = []
    for (var i = 0; i < history.length && out.length < max; i++) if (history[i].time >= oldest) out.push(history[i])
    return out
}
function markRead(history, id) {
    checkHistory(history)
    // the same array when nothing changes (the caller then skips the save)
    if (!history.some(function (r) { return r.id === id && !r.read })) return history
    return history.map(function (r) { return r.id === id && !r.read ? _with(r, true) : r })
}
function markAllRead(history) {
    checkHistory(history)
    return history.map(function (r) { return r.read ? r : _with(r, true) })
}
function removeRecord(history, id) {
    checkHistory(history)
    return history.filter(function (r) { return r.id !== id })
}
// { unread: int, allowlisted: bool } for the unread dot.
function unreadInfo(history, allowlist) {
    checkHistory(history)
    var n = 0, allow = false
    for (var i = 0; i < history.length; i++) {
        if (history[i].read) continue
        n++
        if (!allow && isAllowlisted(history[i], allowlist)) allow = true
    }
    return { unread: n, allowlisted: allow }
}
// Persistence: the state file's JSON text, and the history read back (records not live).
// keep: the ids the server still tracks at load (after a reload with keepOnReload, which P-23
// limits to APTUS_DEV runs); their records keep their id, every other one gets ARCHIVE_ID − index.
function serialise(history) {
    checkHistory(history)
    return JSON.stringify({ version: 1, history: history.map(function (r) {
        var o = {}
        for (var i = 0; i < FIELDS.length; i++) o[FIELDS[i]] = r[FIELDS[i]]
        return o
    }) }, null, 1)
}
function parse(text, now, max, days, keep) {
    invariant(typeof text === "string", "state text is not a string")
    invariant(max >= 1 && days >= 1, "history limits " + max + "/" + days)
    invariant(!keep || Array.isArray(keep), "kept ids are not a list")
    var data
    try { data = JSON.parse(text) } catch (e) { return [] }
    var list = data && Array.isArray(data.history) ? data.history : []
    var out = [], seen = {}
    for (var i = 0; i < list.length; i++) {
        var r = list[i]
        if (!r || typeof r.id !== "number" || typeof r.time !== "number" || seen[r.id]) continue
        seen[r.id] = true
        var c = makeRecord({ id: r.id, appName: r.appName, appIcon: r.appIcon, desktopEntry: r.desktopEntry,
                             summary: r.summary, body: "", image: r.image, urgency: r.urgency, actions: [] }, r.time)
        c.body = reduceMarkup(String(r.body || ""))      // reduced when stored; again for safety
        c.read = !!r.read
        c.held = isHoldReason(r.held) ? r.held : ""
        c.progress = -1
        out.push(c)
    }
    out.sort(function (a, b) { return b.time - a.time })
    var kept = keep || [], valid = []
    for (var j = 0; j < out.length; j++) {
        if (kept.indexOf(out[j].id) < 0) out[j].id = ARCHIVE_ID - j      // server ids restart with the shell
        try { checkRecord(out[j]) } catch (e) { continue }               // file data: dropped, never thrown
        valid.push(out[j])
    }
    var result = trimHistory(valid, max, days, now)
    checkHistory(result)
    return result
}

function _lower(s) { return String(s || "").toLowerCase() }
function _escape(text) {
    return text.replace(/&(?!(?:[a-zA-Z]+|#[0-9]+|#x[0-9a-fA-F]+);)/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}
function _with(r, read) { var c = {}; for (var k in r) c[k] = r[k]; c.read = read; return c }
var FIELDS = ["id", "appName", "appIcon", "desktopEntry", "summary", "body", "image", "urgency", "actions",
              "hasDefault", "resident", "reply", "progress", "time", "read", "held"]

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
