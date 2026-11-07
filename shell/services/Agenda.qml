pragma Singleton
// Agenda: events, reminders, meeting links (agenda.json).
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // [{ uid, title, start: Date, end: Date, allDay: bool, calendar, colour, location, link, description }]
    property var events: []
    // the next event today
    property var next: null
}
