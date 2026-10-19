pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme

// Month view with a header (month, back, today, forward), weekday row and six weeks. Scales with its width and cell height.
Item {
    id: mv

    property var calendarState
    property int cellHeight: 34
    property var anchorMonth: new Date()  // the month on show

    readonly property var english: Qt.locale("en_GB")
    readonly property var days: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    readonly property var grid: mv.calendarState ? mv.calendarState.monthGrid(anchorMonth) : []

    function sameDay(a: var, b: var): bool {
        return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }

    function shiftMonth(delta: int): void {
        anchorMonth = new Date(anchorMonth.getFullYear(), anchorMonth.getMonth() + delta, 1)
    }

    implicitWidth: 300
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 6

        Item {
            width: parent.width
            height: 32

            Label {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: mv.english.toString(mv.anchorMonth, "MMMM yyyy")
                font.weight: Font.DemiBold
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 2
                Repeater {
                    model: [{ t: "‹", d: -1 }, { t: "Today", d: 0 }, { t: "›", d: 1 }]
                    delegate: Item {
                        id: nav
                        required property var modelData
                        width: modelData.d === 0 ? 52 : 32
                        height: 32
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Tokens.surfaceAlt
                            opacity: navArea.pressed ? 1 : navArea.containsMouse ? 0.7 : 0
                            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                        }
                        Label {
                            anchors.centerIn: parent
                            text: nav.modelData.t
                            color: Tokens.inkSoft
                        }
                        MouseArea {
                            id: navArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: nav.modelData.d === 0 ? mv.anchorMonth = new Date() : mv.shiftMonth(nav.modelData.d)
                        }
                    }
                }
            }
        }

        Grid {
            columns: 7
            Repeater {
                model: mv.days
                delegate: Item {
                    required property string modelData
                    width: column.width / 7
                    height: 24
                    Label {
                        anchors.centerIn: parent
                        text: parent.modelData
                        role: Enums.TextRole.Bar
                        color: Tokens.inkFaint
                    }
                }
            }
            Repeater {
                model: mv.grid
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property bool isToday: mv.sameDay(modelData.date, mv.calendarState ? mv.calendarState.today : null)
                    readonly property bool isSelected: mv.sameDay(modelData.date, mv.calendarState ? mv.calendarState.selectedDate : null)
                    readonly property var dots: mv.calendarState ? mv.calendarState.dotsOn(modelData.date) : []
                    width: column.width / 7
                    height: mv.cellHeight

                    // The day number sits in a circle (today = filled, selected = ring); the calendar dots sit below it, never inside.
                    readonly property real circle: Math.min(mv.cellHeight - 10, 34)
                    readonly property real pad: (mv.cellHeight - (circle + 9)) / 2

                    Rectangle {
                        x: (parent.width - width) / 2
                        y: cell.pad
                        width: cell.circle
                        height: width
                        radius: width / 2
                        color: cell.isToday ? Tokens.ink : "transparent"
                        border.width: cell.isSelected && !cell.isToday ? 1 : 0
                        border.color: Tokens.inkSoft
                    }
                    Label {
                        x: (parent.width - width) / 2
                        y: cell.pad + (cell.circle - height) / 2
                        text: cell.modelData.day
                        color: cell.isToday ? Tokens.bg : (cell.modelData.inMonth ? Tokens.ink : Tokens.inkFaint)
                        font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                    }
                    Row {
                        x: (parent.width - width) / 2
                        y: cell.pad + cell.circle + 4
                        spacing: 3
                        Repeater {
                            model: cell.dots
                            delegate: Rectangle {
                                required property string modelData
                                width: 5
                                height: 5
                                radius: 2.5
                                color: modelData
                                opacity: cell.modelData.inMonth ? 1 : 0.45
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: mv.calendarState.selectDate(cell.modelData.date)
                    }
                }
            }
        }
    }
}
