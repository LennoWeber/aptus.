pragma Singleton
pragma ComponentBehavior: Bound
// Lease: isolation status for the bar warning, the notch's one-time message and the settings page.
// Read-only view of <state>/lease/journal.json, <runtime>/guard.state and <runtime>/session.json
// (02-isolation §5, §7); it never writes any of them.
// Owner: S2.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import "lease.js" as LeaseJs

Singleton {
    id: root

    // Journal state: "taking" | "held" | "releasing" | "released" | "" (no journal yet).
    property string state: ""
    // The parsed journal (02 §5.2), null when there is none or it does not parse.
    property var journal: null
    // guard.state: "ok" | "scope-only" | "failed" | "released" | "" (no guard).
    property string guard: ""
    // Session mode from session.json: "lease" | "scope-only" | "".
    property string mode: ""
    // Why the session runs scope-only (session.json "reasons").
    property var reasons: []
    // Slot ids whose write or restore failed (journal slots with status "failed").
    property var failedSlots: []
    // The notch's one-time message for this session (S3 shows it once), "" for nothing to say.
    property string notice: ""
    // true while something needs Lenno's eye: scope-only, a failed slot, a failed guard.
    property bool warning: false
    // One line for the settings page ("Lease held · 31 slots", "Scope-only · another session is open").
    property string statusLine: ""

    // The files' texts ("" while a file is missing: the journal goes to history/ on release).
    property string _journalText: ""
    property string _guardText: ""
    property string _sessionText: ""

    // Update every property above from the three texts through lease.js summarize().
    function refresh(): void {
        const j = _parse(_journalText);
        const s = LeaseJs.summarize(j, LeaseJs.parseGuard(_guardText), _parse(_sessionText));
        journal = j;
        state = s.state;
        guard = s.guard;
        mode = s.mode;
        reasons = s.reasons;
        failedSlots = s.failedSlots;
        notice = s.notice;
        warning = s.warning;
        statusLine = s.statusLine;
    }

    // JSON text → object; null for an empty, missing or broken file.
    function _parse(text: string): var {
        if (!text)
            return null;
        try {
            const v = JSON.parse(text);
            return v !== null && typeof v === "object" ? v : null;
        } catch (e) {
            return null;
        }
    }

    // A missing file reads as "". The journal is removed on release, which a watch on it may
    // miss, so a change of guard.state or session.json re-reads the journal too.
    FileView {
        id: journalView
        path: Paths.leaseJournal
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { root._journalText = text(); root.refresh(); }
        onLoadFailed: { root._journalText = ""; root.refresh(); }
    }
    FileView {
        path: Paths.guardState
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { root._guardText = text(); journalView.reload(); }
        onLoadFailed: { root._guardText = ""; journalView.reload(); }
    }
    FileView {
        path: Paths.sessionStatus
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { root._sessionText = text(); journalView.reload(); }
        onLoadFailed: { root._sessionText = ""; journalView.reload(); }
    }
}
