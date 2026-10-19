pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the clock dropdown.
Item {
    id: dd

    property var calendarState
    signal moreRequested(int tileId)  // opens the control center on a tile

    implicitWidth: 300
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 6

        MonthView {
            width: parent.width
            calendarState: dd.calendarState
            cellHeight: 34
        }

        Rectangle { width: parent.width; height: 1; color: Tokens.line }

        Label {
            readonly property var list: dd.calendarState ? dd.calendarState.eventsOn(dd.calendarState.selectedDate) : []
            visible: list.length === 0
            text: "No events"
            color: Tokens.inkFaint
        }
        Repeater {
            model: dd.calendarState ? dd.calendarState.eventsOn(dd.calendarState.selectedDate).slice(0, 4) : []
            delegate: EventRow {
                required property var modelData
                width: column.width
                event: modelData
            }
        }

        Item { width: 1; height: 6 }
        ActionButton {
            text: "More"
            onClicked: dd.moreRequested(Enums.TileId.Calendar)
        }
    }
}
