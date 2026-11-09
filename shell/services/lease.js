.pragma library
// Pure helpers of the Lease service (02-isolation §5, §7): turn journal.json, guard.state and
// session.json into what the bar, the notch and the settings page show. No I/O here.

// The notch's texts (lib/aptus/lease/preflight.py NOTICE_*; the session writes one into
// session.json, the guard's "failed" adds the last).
var NOTICE_FAILED = "Some apps could not be themed — they keep Noctalia's colours."

// guard.state text ("ok\n<detail>") → { state, detail }; "" for an empty or missing file.
function parseGuard(text) {
    // TODO(S2): first line = state, second = detail; "" → { state: "", detail: "" }.
    throw new Error("lease.parseGuard: not implemented")
}

// The ids of journal slots whose status is "failed" ([] without a journal).
function failedSlots(journal) {
    // TODO(S2): journal.slots filtered by status === "failed", their ids.
    throw new Error("lease.failedSlots: not implemented")
}

// journal (object|null), guard ({state, detail}), session (object|null) →
// { state, guard, mode, reasons, failedSlots, notice, warning, statusLine }.
function summarize(journal, guard, session) {
    // TODO(S2): mode from session.mode, or "scope-only" when guard.state is "scope-only" (another
    //   session opened mid-session); notice = session.notice, or NOTICE_FAILED for failed slots or
    //   guard "failed"; warning = mode scope-only || failed; statusLine per settings.md §7.
    throw new Error("lease.summarize: not implemented")
}
