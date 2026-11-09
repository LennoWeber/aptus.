pragma Singleton
// Lease: isolation status for the bar warning, the notch's one-time message and the settings page.
// Read-only view of <state>/lease/journal.json, <runtime>/guard.state and <runtime>/session.json
// (02-isolation §5, §7); it never writes any of them.
// Owner: S2.
import QtQuick
import Quickshell

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

    // Re-read the three files and update every property above from lease.js summarize().
    function refresh(): void {
        // phase 7
    }
}
