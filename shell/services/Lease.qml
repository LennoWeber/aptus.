pragma Singleton
// Lease: isolation status for the bar warning and the settings page (journal.json, read-only).
// Owner: S2. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // "held" | "released" | "scope-only" | "failed" | ""
    property string state: ""
    property var journal: null
    // guard.state: "ok" | "scope-only" | "failed"
    property string guard: ""
}
