import QtQuick
import qs.models
import qs.theme

// One calendar event: a bar in the calendar's colour, the time, the title and the calendar's name.
Item {
    id: row

    property var event  // { title, start, end, allDay, calendarName, color }
    readonly property string timeText: {
        if (!event) return ""
        if (event.allDay) return "All day"
        const s = Qt.formatTime(new Date(event.start), "HH:mm")
        return event.end && new Date(event.end) > new Date(event.start) ? s + " to " + Qt.formatTime(new Date(event.end), "HH:mm") : s
    }

    implicitWidth: 260
    implicitHeight: 44

    Rectangle {
        x: 0
        anchors { top: parent.top; bottom: parent.bottom; topMargin: 3; bottomMargin: 3 }
        width: 4
        radius: 2
        color: row.event ? row.event.color : Tokens.line
    }
    Column {
        anchors { left: parent.left; leftMargin: 14; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 1
        Label {
            width: parent.width
            elide: Text.ElideRight
            text: row.event ? row.event.title : ""
            font.weight: Font.Medium
        }
        Label {
            width: parent.width
            elide: Text.ElideRight
            text: row.timeText + (row.event && row.event.calendarName ? "   " + row.event.calendarName : "")
            role: Enums.TextRole.Bar
            color: Tokens.inkSoft
            tabularNumbers: true
        }
    }
}
