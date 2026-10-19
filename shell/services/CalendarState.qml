import QtQuick
import Quickshell

// Calendar state for the control center tile and the clock dropdown.
Scope {
    id: root

    property string sourceKind   // "ics" | "google"
    property bool connected      // account/feed reachable
    property string accountLabel // e.g. the Google account address
    property var today: new Date()  // Date
    property var selectedDate: new Date()  // Date
    property var events: []      // list of { id, title, start, end, allDay, calendarName }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        onDateChanged: root.today = clock.date
    }

    function refresh(): void {
        // TODO(phase 7, later): start with a private iCal address, read-only; Google sign-in comes later.
        // Until a source is connected there are no events, the month view still works.
    }

    function selectDate(date: var): void {
        selectedDate = date
    }

    function eventsOn(date: var): var {
        return events.filter(e => {
            const s = new Date(e.start)
            return s.getFullYear() === date.getFullYear() && s.getMonth() === date.getMonth() && s.getDate() === date.getDate()
        })
    }

    // 6 weeks x 7 days for the month of `anchor`, Monday first.
    function monthGrid(anchor: var): var {
        const first = new Date(anchor.getFullYear(), anchor.getMonth(), 1)
        const offset = (first.getDay() + 6) % 7
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - offset + i)
            out.push({ date: d, day: d.getDate(), inMonth: d.getMonth() === anchor.getMonth() })
        }
        return out
    }
}
