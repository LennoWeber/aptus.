// The notification logic (services/js/notifications.js): the interruption policy of 05 §8, toast
// timing, stacks, held summaries, markup and the history (notch.md §6).
import QtQuick
import QtTest
import "../../shell/services/js/notifications.js" as N
import "../../shell/core/js/rules.js" as R

TestCase {
    name: "notifylogic"

    // Tokens.surfaces.toast's timing as theme/tokens.json has it.
    readonly property var timing: ({ minTimeoutMs: 4000, maxTimeoutMs: 9000, perCharMs: 40, actionsExtraMs: 3000, baseTimeoutMs: 4000 })
    function rec(extra) {
        const src = { id: 1, appName: "Mail", appIcon: "mail", desktopEntry: "org.gnome.Evolution", summary: "Hello",
                      body: "", urgency: 1, actions: [] }
        for (const k in extra) src[k] = extra[k]
        return N.makeRecord(src, 1000)
    }
    function ctx(extra) {
        const c = { dnd: false, focus: false, fullscreen: false, overFullscreen: "critical", allowlist: [], muted: {}, now: 1000 }
        for (const k in extra) c[k] = extra[k]
        return c
    }

    function test_policy_table() {
        compare(N.decide(rec({}), ctx({})), { show: "toast", priority: 0, reason: "" })
        compare(N.decide(rec({ urgency: 0 }), ctx({})), { show: "today", priority: 0, reason: "low" })
        compare(N.decide(rec({ urgency: 0 }), ctx({ focus: true })), { show: "held", priority: 0, reason: "focus" })
        compare(N.decide(rec({}), ctx({ focus: true })).reason, "focus")
        compare(N.decide(rec({}), ctx({ dnd: true })).reason, "dnd")
        compare(N.decide(rec({}), ctx({ focus: true, dnd: true })).reason, "focus")     // focus names it first
        compare(N.decide(rec({}), ctx({ fullscreen: true })), { show: "held", priority: 0, reason: "fullscreen" })
        compare(N.decide(rec({}), ctx({ fullscreen: true, overFullscreen: "all" })).show, "toast")
        compare(N.decide(rec({ urgency: 2 }), ctx({ dnd: true, focus: true, fullscreen: true })),
                { show: "toast", priority: N.CRITICAL_PRIORITY, reason: "" })
    }
    function test_allowlist_overrides_dnd_and_focus() {
        compare(N.decide(rec({}), ctx({ dnd: true, focus: true, allowlist: ["MAIL"] })).show, "toast")
        compare(N.decide(rec({}), ctx({ dnd: true, allowlist: ["org.gnome.evolution"] })).show, "toast")   // desktop entry
        verify(!N.isAllowlisted(rec({}), ["", "slack"]))
        // fullscreen still holds an allowlisted app (notch.overFullscreen decides)
        compare(N.decide(rec({}), ctx({ fullscreen: true, allowlist: ["Mail"] })).reason, "fullscreen")
    }
    function test_muted_app_goes_to_today() {
        compare(N.decide(rec({}), ctx({ muted: { Mail: 5000 } })), { show: "today", priority: 0, reason: "muted" })
        compare(N.decide(rec({}), ctx({ muted: { Mail: 5000 }, now: 6000 })).show, "toast")         // the hour is over
        compare(N.decide(rec({ urgency: 2 }), ctx({ muted: { Mail: 5000 } })).show, "toast")         // critical is never muted
        compare(N.MUTE_MS, 3600000)
    }
    function test_progress_hint() {
        compare(N.progressOf({ value: 42.6 }), 43)
        compare(N.progressOf({ value: 150 }), 100)
        compare(N.progressOf({ value: "x" }), -1)
        compare(N.progressOf({}), -1)
        compare(N.progressOf(null), -1)
        compare(rec({ hints: { value: 50 } }).progress, 50)
        compare(N.decide(rec({ hints: { value: 50 } }), ctx({ dnd: true })).show, "progress")
        compare(N.decide(rec({ hints: { value: 100 } }), ctx({})).show, "toast")                    // done: a normal toast
    }
    function test_timeout_formula() {
        compare(N.toastTimeout(rec({}), "auto", timing), 4200)                                       // 4 s + 40 ms × 5
        compare(N.toastTimeout(rec({ body: "x".repeat(200) }), "auto", timing), 9000)                // clamped
        compare(N.toastTimeout(rec({ summary: "", body: "<b>ab</b>" }), "auto", timing), 4080)      // visible text only
        compare(N.toastTimeout(rec({ actions: [{ id: "ok", text: "OK" }] }), "auto", timing), 7200)  // + 3 s with actions
        compare(N.toastTimeout(rec({ hasInlineReply: true }), "auto", timing), 7200)
        compare(N.toastTimeout(rec({ urgency: 2 }), "auto", timing), 0)                             // until dismissed
    }
    function test_timeout_setting() {
        compare(N.toastTimeout(rec({}), "8", timing), 8000)
        compare(N.toastTimeout(rec({}), 8, timing), 8000)
        compare(N.toastTimeout(rec({ actions: [{ id: "ok", text: "OK" }] }), "8", timing), 11000)
        compare(N.toastTimeout(rec({}), "0", timing), 4200)                                          // not a timeout: auto
        compare(N.toastTimeout(rec({ urgency: 2 }), "8", timing), 0)
    }
    function test_stack_window() {
        const a = N.stackStep(null, rec({}), 7, "eDP-1", 1000, 8000)
        verify(!a.joins)
        compare(a.stack.count, 1)
        compare(a.stack.passiveId, 7)
        const b = N.stackStep(a.stack, rec({ id: 2, appName: "Chat", appIcon: "chat" }), 9, "eDP-1", 3000, 8000)
        verify(b.joins)
        compare(b.stack.passiveId, 7)
        compare(b.stack.count, 2)
        compare(b.stack.apps, ["Chat", "Mail"])
        compare(N.stackStep(b.stack, rec({ id: 3 }), 9, "eDP-1", 4000, 8000).stack.apps, ["Chat", "Mail"])   // the same app again
        verify(!N.stackStep(b.stack, rec({ id: 3 }), 9, "DP-3", 4000, 8000).joins)                // another monitor
        verify(!N.stackStep(b.stack, rec({ id: 3 }), 9, "eDP-1", 20000, 8000).joins)              // after the window
        verify(!N.stackStep({ passiveId: 0, monitor: "eDP-1", count: 2, icons: ["chat", "mail"], apps: ["Chat", "Mail"], last: 3000 }, rec({}), 9, "eDP-1", 4000, 8000).joins)
        let s = a.stack
        for (let i = 0; i < 5; i++) s = N.stackStep(s, rec({ id: 10 + i, appName: "App" + i, appIcon: "i" + i }), 9, "eDP-1", 1000, 8000).stack
        compare(s.icons.length, 3)                                                                   // three icons at most
        const p = N.stackPayload(b.stack, rec({ id: 2, summary: "Newest" }), 5000)
        compare(p.summary, "2 notifications")
        compare(p.body, "Newest")
        compare(p.nid, 0)
        compare(p.actions, [])
        compare(p.opens, "today")
        compare(p.stack.count, 2)
    }
    function test_held_summary() {
        const one = N.heldPayload(1, "focus", 5000)
        compare(one.summary, "1 notification while you were focused")
        compare(one.opens, "today")
        compare(one.glyph, "notifications")
        compare(one.timeout, 5000)
        compare(N.heldPayload(3, "dnd", 5000).summary, "3 notifications during Do not disturb")
        compare(N.heldPayload(2, "fullscreen", 5000).summary, "2 notifications while in fullscreen")
    }
    function test_markup_reduction() {
        compare(N.reduceMarkup("a <b>b</b> <script>x</script> <a href='https://x.y'>l</a>\nz & <q"),
                'a <b>b</b> x <a href="https://x.y">l</a><br>z &amp; &lt;q')
        compare(N.reduceMarkup('<a href="javascript:alert(1)">x</a>'), "<span>x</span>")      // no such links
        compare(N.reduceMarkup("<b>bold"), "<b>bold</b>")                                       // closed at the end
        compare(N.reduceMarkup("<i><b>x</i>y"), "<i><b>x</b></i>y")
        compare(N.reduceMarkup("Tom &amp; Jerry > Spike"), "Tom &amp; Jerry &gt; Spike")
        compare(N.reduceMarkup("<img src=x onerror=y>"), "")
        compare(N.reduceMarkup('<b onclick="x">b</b>'), "<b>b</b>")                            // attributes dropped
        compare(N.plainText("<b>a</b> &amp; b<br>c"), "a & b\nc")
        compare(rec({ body: "<u>x</u>" }).body, "x")
    }
    function test_history_order_trim_and_read() {
        const day = 86400000, now = 10 * day
        const r = (id, time) => { const x = rec({ id: id }); x.time = time; return x }
        let h = []
        h = N.addToHistory(h, r(1, now - 3), 3, 7, now)
        h = N.addToHistory(h, r(2, now - 2), 3, 7, now)
        h = N.addToHistory(h, r(1, now - 1), 3, 7, now)                     // a replace moves it to the top
        compare(h.map(x => x.id), [1, 2])
        h = N.addToHistory(h, r(3, now), 3, 7, now)
        h = N.addToHistory(h, r(4, now), 3, 7, now)
        compare(h.map(x => x.id), [4, 3, 1])                                // max 3
        compare(N.trimHistory([r(5, now), r(6, now - 8 * day)], 10, 7, now).map(x => x.id), [5])   // 7 days
        const read = N.markRead(h, 3)
        verify(read[1].read)
        verify(!h[1].read)                                                  // a new array, the old one kept
        verify(N.markRead(read, 3) === read)                                // found in review: nothing to mark, same array
        verify(N.markRead(read, 99) === read)
        compare(N.unreadInfo(read, []), { unread: 2, allowlisted: false })
        compare(N.unreadInfo(read, ["Mail"]).allowlisted, true)
        verify(N.markAllRead(h).every(x => x.read))
        compare(N.removeRecord(h, 3).map(x => x.id), [4, 1])
    }
    function test_persistence_round_trip() {
        const a = rec({ id: 1, body: "<b>x</b> &amp; y", actions: [{ id: "ok", text: "OK" }] })
        a.time = 2000
        a.read = true
        a.held = "dnd"
        const b = rec({ id: 2 })
        b.time = 3000
        const back = N.parse(N.serialise([b, a]), 3000, 100, 7)
        compare(back.map(x => x.time), [3000, 2000])
        compare(back.map(x => x.id), [N.ARCHIVE_ID, N.ARCHIVE_ID - 1])     // ids of their own
        compare(back[1].body, a.body)
        verify(back[1].read)
        compare(back[1].held, "dnd")
        compare(back[1].actions, [])                                        // not live: no actions
        verify(!back[1].live)
        compare(back[1].progress, -1)
        compare(N.parse("not json", 0, 100, 7), [])
        compare(N.parse('{"version":1,"history":[{"id":"x","time":1},null,{"id":5}]}', 0, 100, 7), [])
        // the server still tracks 2 (a reload with keepOnReload): its record keeps the id
        compare(N.parse(N.serialise([b, a]), 3000, 100, 7, [2]).map(x => x.id), [2, N.ARCHIVE_ID - 1])
    }
    function test_damaged_state_file_keeps_the_rest() {
        // an unknown hold reason is cleared, an unknown urgency is normal, a repeated id is dropped:
        // the other records survive (a throw would empty the history and the next save the file)
        const ok = '{"id":1,"appName":"Mail","summary":"a","urgency":1,"time":2000'
        const text = '{"version":1,"history":[' + ok + ',"held":"asleep"},' + ok + '},'
                     + '{"id":2,"appName":"Mail","summary":"b","urgency":7,"time":1000},'
                     + '{"id":3,"appName":"Mail","summary":"c","urgency":0,"time":1500,"held":"constructor"}]}'
        const back = N.parse(text, 3000, 100, 7)
        compare(back.map(x => x.summary), ["a", "c", "b"])
        compare(back.map(x => x.held), ["", "", ""])
        compare(back[2].urgency, 1)
    }
    function test_fallback_app_and_glyph() {
        const r = N.makeRecord({ id: 3 }, 0)
        compare(r.appName, N.FALLBACK_APP)
        compare(r.urgency, N.NORMAL)
        compare(N.toastPayload(r, 4000, 3).glyph, N.FALLBACK_GLYPH)
        compare(N.toastPayload(rec({}), 4000, 3).glyph, "")                // the app icon instead
        compare(N.toastPayload(rec({ appIcon: "" }), 4000, 3).appIcon, "org.gnome.Evolution")
        const x = rec({ urgency: 7, hasInlineReply: true,
                        actions: [{ id: "default", text: "Open" }, { id: "inline-reply", text: "Reply" }, { id: "ok", text: "OK" }, null] })
        compare(x.urgency, N.NORMAL)
        compare(x.actions, [{ id: "ok", text: "OK" }])
        verify(x.hasDefault)
        verify(x.reply)
        const many = rec({ actions: [{ id: "a" }, { id: "b" }, { id: "c" }, { id: "d" }] })
        compare(N.toastPayload(many, 4000, 3).actions.length, 3)
        compare(many.actions[0].text, "a")
    }
    function test_system_toast() {
        const t = N.systemToast("Battery low", "10 % left", "battery_alert", false, 5000)
        compare(t.nid, 0)
        compare(t.glyph, "battery_alert")
        compare(t.timeout, 5000)
        compare(t.actions, [])
        compare(N.systemToast("Battery critical", "", "battery_alert", true, 5000).timeout, 0)
        compare(N.systemToast("x", "", "", false, 5000).glyph, N.FALLBACK_GLYPH)
    }
    function test_critical_priority_passes_over_fullscreen() {
        const d = N.decide(rec({ urgency: 2 }), ctx({ fullscreen: true }))
        const m = R.newMonitor("eDP-1")
        m.fullscreen = true
        m.passive = [{ id: 1, kind: "toast", priority: 0, born: 0 }, { id: 2, kind: "toast", priority: d.priority, born: 0 }]
        compare(R.arbitrate(m, 0, { overFullscreen: "critical", expired: true }).entry.id, 2)
        compare(R.arbitrate(m, 0, { overFullscreen: "none", expired: true }).kind, "hidden")
        m.passive = [m.passive[0]]
        compare(R.arbitrate(m, 0, { overFullscreen: "critical", expired: true }).kind, "hidden")
    }

    // An invariant of notifications refuses the call (any other exception is not a refusal).
    function refuses(f) {
        try { f() } catch (e) { return String(e.message).indexOf("notifications invariant:") === 0 }
        return false
    }
    function accepts(f) {
        try { f() } catch (e) { return false }
        return true
    }

    function record(extra) {
        const r = { id: 4, appName: "Mail", appIcon: "", desktopEntry: "", summary: "s", body: "", image: "", urgency: 1,
                    actions: [], hasDefault: false, resident: false, reply: false, progress: -1, time: 0, read: false,
                    live: false, held: "" }
        for (const k in extra) r[k] = extra[k]
        return r
    }
    function test_invariants_reject_broken_state() {
        verify(accepts(() => N.checkRecord(record({}))))
        verify(refuses(() => N.checkRecord(record({ id: 0 }))))
        verify(refuses(() => N.checkRecord(record({ id: 1.5 }))))
        verify(refuses(() => N.checkRecord(record({ appName: "" }))))
        verify(refuses(() => N.checkRecord(record({ urgency: 3 }))))
        verify(refuses(() => N.checkRecord(record({ actions: [{ id: "default", text: "Open" }] }))))
        verify(refuses(() => N.checkRecord(record({ actions: [{ id: "inline-reply", text: "Reply" }] }))))
        verify(refuses(() => N.checkRecord(record({ progress: 101 }))))
        verify(refuses(() => N.checkRecord(record({ held: "asleep" }))))
        verify(refuses(() => N.decide(record({}), ctx({ overFullscreen: "sometimes" }))))
        verify(refuses(() => N.decide(record({}), ctx({ allowlist: "Mail" }))))
        // a decision: critical is never held or sent to Today; only critical toasts have priority 2
        verify(accepts(() => N.checkDecision(record({ urgency: 2 }), { show: "toast", priority: 2, reason: "" })))
        verify(refuses(() => N.checkDecision(record({ urgency: 2 }), { show: "held", priority: 0, reason: "dnd" })))
        verify(refuses(() => N.checkDecision(record({ urgency: 2 }), { show: "today", priority: 0, reason: "muted" })))
        verify(refuses(() => N.checkDecision(record({ urgency: 2 }), { show: "toast", priority: 0, reason: "" })))
        verify(refuses(() => N.checkDecision(record({}), { show: "toast", priority: 2, reason: "" })))
        verify(accepts(() => N.checkDecision(record({ urgency: 2 }), { show: "progress", priority: 2, reason: "" })))
        verify(refuses(() => N.checkDecision(record({ urgency: 2 }), { show: "progress", priority: 0, reason: "" })))
        verify(refuses(() => N.checkDecision(record({}), { show: "held", priority: 0, reason: "constructor" })))
        verify(refuses(() => N.checkDecision(record({}), { show: "held", priority: 0, reason: "" })))
        verify(refuses(() => N.checkDecision(record({}), { show: "popup", priority: 0, reason: "" })))
        // timing and settings
        verify(refuses(() => N.toastTimeout(record({}), "auto", { minTimeoutMs: 9000, maxTimeoutMs: 4000, perCharMs: 40, actionsExtraMs: 0, baseTimeoutMs: 0 })))
        verify(refuses(() => N.toastTimeout(record({}), -1, timing)))
        verify(refuses(() => N.toastPayload(record({}), -1, 3)))
        // stacks and the held summary
        verify(refuses(() => N.stackStep(null, record({}), 0, "eDP-1", 0, -1)))
        verify(refuses(() => N.stackStep({ passiveId: 3, monitor: "eDP-1", count: 0, icons: [], apps: [], last: 0 }, record({}), 0, "eDP-1", 0, 2000)))
        verify(refuses(() => N.stackStep({ passiveId: 3, monitor: "eDP-1", count: 2, icons: ["a"], apps: ["A", "A"], last: 0 }, record({}), 0, "eDP-1", 0, 2000)))
        verify(refuses(() => N.stackPayload({ passiveId: 3, monitor: "eDP-1", count: 1, icons: ["a"], apps: ["A"], last: 0 }, record({}), 4000)))
        verify(refuses(() => N.stackPayload({ passiveId: 0, monitor: "eDP-1", count: 2, icons: ["a"], apps: ["A", "B"], last: 0 }, record({}), 4000)))
        verify(refuses(() => N.checkStack({ passiveId: 3, monitor: "eDP-1", count: 2, icons: [], apps: [], last: 0 })))
        verify(refuses(() => N.checkStack({ passiveId: 3, monitor: "eDP-1", count: 1, icons: ["a"], apps: ["A", "B"], last: 0 })))
        verify(refuses(() => N.checkStack({ passiveId: 3, monitor: "eDP-1", count: 1, icons: null, apps: ["A"], last: 0 })))
        verify(refuses(() => N.heldPayload(0, "dnd", 4000)))
        verify(refuses(() => N.heldPayload(2, "asleep", 4000)))
        verify(refuses(() => N.heldPayload(2, "toString", 4000)))
        verify(refuses(() => N.systemToast(undefined, "", "battery_alert", true, 0)))
        verify(refuses(() => N.systemToast("", "", "battery_alert", false, 4000)))
        verify(refuses(() => N.systemToast("Battery low", "", "battery_alert", false, 0)))
        // markup and the history: strings in, each id once
        verify(refuses(() => N.reduceMarkup(null)))
        verify(refuses(() => N.plainText(undefined)))
        verify(refuses(() => N.checkHistory([record({ id: 1 }), record({ id: 1 })])))
        verify(refuses(() => N.markRead([record({ id: 1 }), record({ id: 1 })], 1)))
        verify(refuses(() => N.addToHistory([], record({}), 0, 7, 0)))
        verify(refuses(() => N.trimHistory([], 100, 0, 0)))
        verify(refuses(() => N.parse(null, 0, 100, 7)))
        verify(refuses(() => N.parse("{}", 0, 100, 7, 2)))
    }
    function test_restart_ids_do_not_collide() {
        // the server's ids start at 1 again with every shell start: a record read back from the
        // state file gets an id of its own, so a new notification never replaces an old record
        const old = record({ id: 1, time: 2000 })
        const back = N.parse(N.serialise([old]), 3000, 100, 7)
        verify(back[0].id <= N.ARCHIVE_ID)
        const fresh = rec({ id: 1 })
        const h = N.addToHistory(back, fresh, 100, 7, 3000)
        compare(h.length, 2)
        compare(h.map(x => x.summary), ["Hello", "s"])
        // read back twice (two restarts): still distinct
        const again = N.parse(N.serialise(h), 3000, 100, 7)
        compare(again.length, 2)
        verify(again.every(x => x.id <= N.ARCHIVE_ID))
        verify(again[0].id !== again[1].id)
    }
}
