pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the night light dropdown.
Item {
    id: dd
    // TODO(phase 7, section 3b): link to the Display tile of the control center (moreRequested).

    property var nightLightState
    property var displayState
    signal moreRequested(int tileId)  // opens the control center on a tile

    implicitWidth: 300
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 2

        ToggleSwitch {
            width: parent.width
            label: "Night light"
            checked: dd.nightLightState ? dd.nightLightState.enabled : false
            onToggled: on => dd.nightLightState.setEnabled(on)
        }

        Row {
            width: parent.width
            spacing: 8
            opacity: dd.nightLightState && dd.nightLightState.enabled ? 1 : 0.45
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            SliderControl {
                width: parent.width - 8 - 56
                from: dd.nightLightState ? dd.nightLightState.minTemperatureK : 3000
                to: dd.nightLightState ? dd.nightLightState.maxTemperatureK : 6500
                step: 100
                value: dd.nightLightState ? dd.nightLightState.temperatureK : 4200
                onMoved: v => dd.nightLightState.setTemperature(v)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                horizontalAlignment: Text.AlignRight
                text: dd.nightLightState ? dd.nightLightState.temperatureK + " K" : ""
                color: Tokens.inkSoft
            }
        }

        ToggleSwitch {
            width: parent.width
            label: dd.nightLightState ? dd.nightLightState.scheduleText : "Evening to morning"
            checked: dd.nightLightState ? dd.nightLightState.scheduled : false
            onToggled: on => dd.nightLightState.setScheduled(on)
        }

        Item { width: 1; height: 10 }

        Label {
            text: "Brightness"
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }

        Row {
            width: parent.width
            spacing: 8
            SliderControl {
                width: parent.width - 8 - 44
                from: 0.01
                value: dd.displayState ? dd.displayState.brightness : 0.5
                onMoved: v => dd.displayState.setBrightness(v)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: dd.displayState ? Math.round(dd.displayState.brightness * 100) + "%" : ""
                color: Tokens.inkSoft
            }
        }
    }
}
