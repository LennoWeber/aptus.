pragma ComponentBehavior: Bound
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
    readonly property var selectedEvents: calendarState ? calendarState.eventsOn(selected) : []

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
        // The next thing today, with the calendar's colour.
        Row {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            spacing: 6
            readonly property var list: tile.calendarState ? tile.calendarState.eventsOn(tile.today) : []
            Rectangle {
                visible: parent.list.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: parent.list.length > 0 ? parent.list[0].color : "transparent"
            }
            Label {
                width: parent.width - (parent.list.length > 0 ? 14 : 0)
                elide: Text.ElideRight
                text: parent.list.length === 0 ? "No events today" : parent.list[0].title + (parent.list.length > 1 ? "  +" + (parent.list.length - 1) : "")
                color: parent.list.length === 0 ? Tokens.inkFaint : Tokens.inkSoft
                role: Enums.TextRole.Bar
            }
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
                visible: tile.selectedEvents.length === 0
                text: "No events"
                color: Tokens.inkSoft
            }
            Flickable {
                width: parent.width
                height: Math.min(contentHeight, 230)
                contentHeight: eventStack.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: eventStack
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: tile.selectedEvents
                        delegate: EventRow {
                            required property var modelData
                            width: eventStack.width
                            event: modelData
                        }
                    }
                }
            }
            Item { width: 1; height: Math.max(0, parent.height - 250 - Math.min(eventStack.height, 230)) }
            Label {
                width: parent.width
                text: tile.calendarState && tile.calendarState.connected ? "Private iCal addresses, read only" : (tile.calendarState && tile.calendarState.error !== "" ? tile.calendarState.error : "No calendar connected yet. Add private iCal addresses in the settings (calendar.sources).")
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
                wrapMode: Text.Wrap
            }
        }
    }
}
