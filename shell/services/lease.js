.pragma library
// Pure helpers of the Lease service (02-isolation §5, §7): turn journal.json, guard.state and
// session.json into what the bar, the notch and the settings page show. No I/O here.

// The notch's texts (lib/aptus/lease/preflight.py NOTICE_*; the session writes one into
// session.json, the guard's "failed" adds the last).
var NOTICE_FAILED = "Some apps could not be themed — they keep Noctalia's colours.";
var REASON_OTHER_SESSION = "another session is open";

// guard.state text ("ok\n<detail>") → { state, detail }; "" for an empty or missing file.
function parseGuard(text) {
    var lines = String(text || "").split("\n");
    return { state: (lines[0] || "").trim(), detail: (lines[1] || "").trim() };
}

// The ids of journal slots whose status is "failed" ([] without a journal).
function failedSlots(journal) {
    if (!journal || !Array.isArray(journal.slots))
        return [];
    return journal.slots.filter(function (s) { return s && s.status === "failed"; })
                        .map(function (s) { return String(s.id); });
}

// "2026-11-09T09:12:30+01:00" → "09:12" ("" when it is not such a time).
function clock(iso) {
    var m = /T(\d\d:\d\d)/.exec(String(iso || ""));
    return m ? m[1] : "";
}

function _statusLine(state, journal, mode, reasons, failed) {
    if (failed.length)
        return "Release incomplete · " + failed.join(", ");
    if (state === "held" || state === "taking") {
        var since = clock(journal.owner ? journal.owner.taken_at : "");
        var slots = Array.isArray(journal.slots) ? journal.slots.length : 0;
        return "Lease held" + (since ? " since " + since : "") + " · " + slots + " slots · generation "
               + (journal.theme_generation || 0);
    }
    if (state === "releasing")
        return "Releasing";
    if (mode === "scope-only")
        return "Scope-only: " + (reasons.length ? reasons[0] : "no lease");
    return "Released";
}

// journal (object|null), guard ({state, detail}), session (object|null) →
// { state, guard, mode, reasons, failedSlots, notice, warning, statusLine }.
function summarize(journal, guard, session) {
    guard = guard || { state: "", detail: "" };
    var state = journal && journal.state ? String(journal.state) : "";
    var failed = failedSlots(journal);
    var mode = session && session.mode ? String(session.mode) : "";
    var reasons = session && Array.isArray(session.reasons) ? session.reasons.map(String) : [];
    var notice = session && session.notice ? String(session.notice) : "";
    if (guard.state === "scope-only") {          // another session opened mid-session
        mode = "scope-only";
        if (reasons.indexOf(REASON_OTHER_SESSION) < 0)
            reasons.unshift(REASON_OTHER_SESSION);
        notice = guard.detail || notice;
    }
    if (failed.length || guard.state === "failed")
        notice = NOTICE_FAILED;
    return {
        state: state,
        guard: guard.state,
        mode: mode,
        reasons: reasons,
        failedSlots: failed,
        notice: notice,
        warning: mode === "scope-only" || failed.length > 0 || guard.state === "failed",
        statusLine: _statusLine(state, journal || {}, mode, reasons, failed)
    };
}
