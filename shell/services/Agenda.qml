pragma Singleton
// Agenda: events, reminders, meeting links (agenda.json).
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property var events: []
    // the next event today
    property var next: null
}
