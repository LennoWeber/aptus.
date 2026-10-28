import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the DisplayTile.
Item {
    id: tile

    property bool expanded
    property var displayState
    property var nightLightState

    readonly property bool nightOn: nightLightState ? nightLightState.enabled : false

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            text: tile.displayState ? Math.round(tile.displayState.brightness * 100) + "%" : ""
            role: Enums.TextRole.Display
            tabularNumbers: true
        }
        Label {
            anchors { right: parent.right; top: parent.top; topMargin: 8 }
            text: tile.nightOn ? "Night light " + tile.nightLightState.temperatureK + " K" : "Night light off"
            color: tile.nightOn ? Tokens.ok : Tokens.inkFaint
        }
        SliderControl {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            from: 0.01
            value: tile.displayState ? tile.displayState.brightness : 0.5
            onMoved: v => tile.displayState.setBrightness(v)
        }
    }

    // Expanded: brightness, night light and the screen itself, three columns across the full width.
    Item {
        anchors.fill: parent
        visible: tile.expanded
        readonly property real colWidth: (width - 2 * 49) / 3

        Column {
            anchors { left: parent.left; top: parent.top }
            width: parent.colWidth
            spacing: 6

            Label {
                text: "Brightness"
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Label {
                text: tile.displayState ? Math.round(tile.displayState.brightness * 100) + "%" : ""
                role: Enums.TextRole.Display
                tabularNumbers: true
            }
            SliderControl {
                width: parent.width
                from: 0.01
                value: tile.displayState ? tile.displayState.brightness : 0.5
                onMoved: v => tile.displayState.setBrightness(v)
            }
            Row {
                width: parent.width
                Label { text: "Dim"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
                Item { width: parent.width - 60; height: 1 }
                Label { text: "Bright"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            }
        }

        Rectangle {
            id: divider
            anchors { left: parent.left; leftMargin: parent.colWidth + 24; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Tokens.line
        }

        Column {
            anchors { left: divider.right; leftMargin: 24; top: parent.top }
            width: parent.colWidth
            spacing: 6

            Label {
                text: "Night light"
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Label {
                text: tile.nightLightState ? tile.nightLightState.temperatureK + " K" : ""
                role: Enums.TextRole.Display
                tabularNumbers: true
                color: tile.nightOn ? Tokens.ink : Tokens.inkFaint
            }
            SliderControl {
                width: parent.width
                opacity: tile.nightOn ? 1 : 0.45
                from: tile.nightLightState ? tile.nightLightState.minTemperatureK : 3000
                to: tile.nightLightState ? tile.nightLightState.maxTemperatureK : 6500
                step: 100
                value: tile.nightLightState ? tile.nightLightState.temperatureK : 4200
                onMoved: v => tile.nightLightState.setTemperature(v)
            }
            Row {
                width: parent.width
                Label { text: "Warmer"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
                Item { width: parent.width - 100; height: 1 }
                Label { text: "Cooler"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            }
            Item { width: 1; height: 14 }
            ToggleSwitch {
                width: parent.width
                label: "Night light"
                checked: tile.nightOn
                onToggled: on => tile.nightLightState.setEnabled(on)
            }
            ToggleSwitch {
                width: parent.width
                label: "Evening to morning (20:00 to 07:00)"
                checked: tile.nightLightState ? tile.nightLightState.scheduled : false
                onToggled: on => tile.nightLightState.setScheduled(on)
            }
        }

        Rectangle {
            id: divider2
            anchors { left: parent.left; leftMargin: 2 * parent.colWidth + 73; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Tokens.line
        }

        Column {
            anchors { left: divider2.right; leftMargin: 24; top: parent.top; right: parent.right }
            spacing: 6

            Label {
                text: "Screen"
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Label {
                text: tile.displayState && tile.displayState.output ? tile.displayState.widthPx + " x " + tile.displayState.heightPx : ""
                role: Enums.TextRole.Display
                tabularNumbers: true
            }
            Label {
                text: tile.displayState ? tile.displayState.output : ""
                role: Enums.TextRole.Mono
                color: Tokens.inkFaint
            }
            Item { width: 1; height: 10 }
            Label { text: "Scale"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            SegmentedControl {
                width: parent.width
                options: tile.displayState ? tile.displayState.scaleChoices.map(f => ({ label: Math.round(f * 100) + "%", value: f })) : []
                current: tile.displayState ? tile.displayState.scale : 1
                onPicked: v => tile.displayState.setScale(v)
            }
            Item { width: 1; height: 6 }
            Label { text: "Refresh rate"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            SegmentedControl {
                width: parent.width
                options: tile.displayState ? tile.displayState.refreshChoices.map(h => ({ label: Math.round(h) + " Hz", value: h })) : []
                current: tile.displayState ? tile.displayState.refreshHz : 60
                onPicked: v => tile.displayState.setRefresh(v)
            }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: tile.displayState && tile.displayState.refreshHz < 55 ? "A lower rate saves battery." : "The panel offers one resolution."
                color: Tokens.inkSoft
            }
        }
    }
}
