// The Lease service's pure helpers (shell/services/lease.js, 02-isolation §5, §7).
import QtQuick
import QtTest
import "../../shell/services/lease.js" as Lib

TestCase {
    name: "lease"

    readonly property var held: ({
        state: "held", theme_generation: 37,
        owner: { taken_at: "2026-11-09T09:12:30+01:00", hyprland_pid: 4242 },
        slots: [{ id: "gtk3.artifact", status: "held" }, { id: "kde.colors", status: "held" }]
    })

    function test_parse_guard() {
        compare(Lib.parseGuard("ok\n\n"), { state: "ok", detail: "" })
        compare(Lib.parseGuard("scope-only\nAnother session is open\n").detail, "Another session is open")
        compare(Lib.parseGuard(""), { state: "", detail: "" })
        compare(Lib.parseGuard(undefined).state, "")
    }

    function test_failed_slots() {
        compare(Lib.failedSlots(null), [])
        compare(Lib.failedSlots({ slots: [{ id: "a.b", status: "failed" }, { id: "c.d", status: "restored" }] }), ["a.b"])
    }

    function test_held() {
        var s = Lib.summarize(held, { state: "ok", detail: "" }, { mode: "lease", reasons: [], notice: "" })
        compare(s.state, "held")
        compare(s.mode, "lease")
        compare(s.warning, false)
        compare(s.notice, "")
        compare(s.statusLine, "Lease held since 09:12 · 2 slots · generation 37")
    }

    function test_scope_only_at_start() {
        var session = { mode: "scope-only", reasons: ["another session is open"],
                        notice: "Another session is open — some apps keep Noctalia's colours." }
        var s = Lib.summarize(null, { state: "ok", detail: "" }, session)
        compare(s.warning, true)
        compare(s.notice, session.notice)
        compare(s.statusLine, "Scope-only: another session is open")
    }

    function test_released_mid_session() {
        // the guard released because Umbriel logged in: the session says lease, the guard knows better
        var s = Lib.summarize(null, { state: "scope-only", detail: "Another session is open — some apps keep Noctalia's colours." },
                              { mode: "lease", reasons: [], notice: "" })
        compare(s.mode, "scope-only")
        compare(s.reasons, ["another session is open"])
        compare(s.notice, "Another session is open — some apps keep Noctalia's colours.")
        verify(s.warning)
    }

    function test_failures() {
        var j = { state: "releasing", slots: [{ id: "gtk3.artifact", status: "failed" }] }
        var s = Lib.summarize(j, { state: "failed", detail: "" }, null)
        compare(s.failedSlots, ["gtk3.artifact"])
        compare(s.notice, Lib.NOTICE_FAILED)
        compare(s.statusLine, "Release incomplete · gtk3.artifact")
        verify(s.warning)
        compare(Lib.summarize(null, { state: "", detail: "" }, null).statusLine, "Released")
    }
}
