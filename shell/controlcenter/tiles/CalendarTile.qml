import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the CalendarTile.
Item {
    id: tile

    property bool expanded
    property var calendarState

    readonly property var english: Qt.locale("en_GB")
    readonly property var today: calendarState ? calendarState.today : new Date()
    readonly property var selected: calendarState ? calendarState.selectedDate : new Date()

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            text: tile.english.toString(tile.today, "d")
            role: Enums.TextRole.Display
            tabularNumbers: true
        }
        Label {
            anchors { left: parent.left; top: parent.top; topMargin: 48 }
            text: tile.english.toString(tile.today, "dddd")
            font.weight: Font.Medium
        }
        Label {
            anchors { left: parent.left; top: parent.top; topMargin: 68 }
            text: tile.english.toString(tile.today, "MMMM yyyy")
            color: Tokens.inkSoft
        }
        Label {
            anchors { left: parent.left; bottom: parent.bottom }
            readonly property var list: tile.calendarState ? tile.calendarState.eventsOn(tile.today) : []
            text: list.length === 0 ? "No events today" : list[0].title
            color: Tokens.inkFaint
            role: Enums.TextRole.Bar
        }
    }

    // Expanded: a large month on the left, the day with its events on the right.
    Item {
        anchors.fill: parent
        visible: tile.expanded

        MonthView {
            id: month
            anchors { left: parent.left; top: parent.top }
            width: parent.width * 0.58
            calendarState: tile.calendarState
            cellHeight: Math.max(34, Math.floor((tile.height - 32 - 24 - 18) / 6))
        }

        Rectangle {
            id: divider
            anchors { left: month.right; leftMargin: 24; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Tokens.line
        }

        Column {
            anchors { left: divider.right; leftMargin: 24; top: parent.top; right: parent.right; bottom: parent.bottom }
            spacing: 4

            Label {
                text: tile.english.toString(tile.selected, "dddd")
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Label {
                text: tile.english.toString(tile.selected, "d MMMM")
                role: Enums.TextRole.Title
            }
            Item { width: 1; height: 12 }
            Label {
                width: parent.width
                readonly property var list: tile.calendarState ? tile.calendarState.eventsOn(tile.selected) : []
                text: list.length === 0 ? "No events" : list.map(e => (e.allDay ? "" : Qt.formatTime(new Date(e.start), "HH:mm") + "  ") + e.title + (e.calendarName ? "  (" + e.calendarName + ")" : "")).join("\n")
                color: Tokens.inkSoft
                wrapMode: Text.Wrap
            }
            Item { width: 1; height: Math.max(0, parent.height - 220) }
            Label {
                width: parent.width
                text: tile.calendarState && tile.calendarState.connected ? "Source: " + tile.calendarState.sourceKind : "No calendar connected yet. A private iCal address will be added in the settings."
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
                wrapMode: Text.Wrap
            }
        }
    }
}
