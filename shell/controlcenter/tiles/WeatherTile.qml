pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the WeatherTile. Compact: now; expanded: hours, days and the source.
Item {
    id: tile

    property bool expanded
    property var weatherState

    readonly property bool ready: weatherState ? weatherState.loaded : false
    readonly property var english: Qt.locale("en_GB")

    function deg(v: real): string {
        return Math.round(v) + "°"
    }

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            y: -4
            text: tile.ready ? tile.deg(tile.weatherState.temperatureC) : "–"
            role: Enums.TextRole.Display
            tabularNumbers: true
            color: tile.ready ? Tokens.ink : Tokens.inkFaint
        }
        Label {
            anchors { left: parent.left; bottom: parent.bottom; right: icon.left; rightMargin: 8 }
            elide: Text.ElideRight
            text: tile.ready ? tile.weatherState.condition + (tile.weatherState.daily.length > 0 ? ", " + tile.deg(tile.weatherState.daily[0].minC) + " to " + tile.deg(tile.weatherState.daily[0].maxC) : "")
                : (tile.weatherState && tile.weatherState.error !== "" ? tile.weatherState.error : "Loading")
            color: Tokens.inkSoft
        }
        StatusGlyph {
            id: icon
            anchors { right: parent.right; top: parent.top }
            width: 34
            height: 34
            kind: tile.ready ? tile.weatherState.iconName : "cloud"
            color: tile.ready ? Tokens.ink : Tokens.inkFaint
        }
    }

    Item {
        anchors.fill: parent
        visible: tile.expanded

        // Now
        Item {
            id: now
            width: parent.width
            height: 84

            StatusGlyph {
                id: bigIcon
                x: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                height: 56
                kind: tile.ready ? tile.weatherState.iconName : "cloud"
            }
            Label {
                id: bigTemp
                anchors { left: bigIcon.right; leftMargin: 18; verticalCenter: parent.verticalCenter }
                text: tile.ready ? tile.deg(tile.weatherState.temperatureC) : "–"
                font.pixelSize: 54
                font.weight: Font.Light
                role: Enums.TextRole.Display
                tabularNumbers: true
            }
            Column {
                anchors { left: bigTemp.right; leftMargin: 20; verticalCenter: parent.verticalCenter }
                spacing: 2
                Label { text: tile.ready ? tile.weatherState.condition : "Loading"; role: Enums.TextRole.Title }
                Label {
                    text: tile.weatherState ? tile.weatherState.locationName + (tile.ready ? ", feels like " + tile.deg(tile.weatherState.feelsLikeC) : "") : ""
                    color: Tokens.inkSoft
                }
            }
        }

        Rectangle { id: line1; anchors.top: now.bottom; width: parent.width; height: 1; color: Tokens.line }

        // Next hours
        Row {
            id: hours
            anchors { top: line1.bottom; topMargin: 14 }
            width: parent.width
            Repeater {
                model: tile.ready ? tile.weatherState.hourly : []
                delegate: Column {
                    id: hourCol
                    required property var modelData
                    width: hours.width / 12
                    spacing: 6
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: hourCol.modelData.time.getHours() + ""
                        role: Enums.TextRole.Bar
                        color: Tokens.inkFaint
                    }
                    StatusGlyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 22
                        height: 22
                        kind: hourCol.modelData.iconName
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.deg(hourCol.modelData.temperatureC)
                        tabularNumbers: true
                    }
                }
            }
        }

        Rectangle { id: line2; anchors { top: hours.bottom; topMargin: 14 } width: parent.width; height: 1; color: Tokens.line }

        // Next days
        Column {
            anchors { top: line2.bottom; topMargin: 6; left: parent.left; right: parent.right }
            Repeater {
                model: tile.ready ? tile.weatherState.daily.slice(1) : []
                delegate: Item {
                    id: dayRow
                    required property var modelData
                    width: parent.width
                    height: 34
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 60
                        text: tile.english.toString(dayRow.modelData.date, "ddd")
                        font.weight: Font.Medium
                    }
                    StatusGlyph {
                        x: 70
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        kind: dayRow.modelData.iconName
                    }
                    Label {
                        x: 108
                        anchors.verticalCenter: parent.verticalCenter
                        text: dayRow.modelData.condition
                        color: Tokens.inkSoft
                    }
                    Label {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: tile.deg(dayRow.modelData.minC) + "   " + tile.deg(dayRow.modelData.maxC)
                        tabularNumbers: true
                    }
                }
            }
        }

        Label {
            anchors { left: parent.left; bottom: parent.bottom }
            text: "Weather data by Open-Meteo.com (CC BY 4.0)"
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }
    }
}
