pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the battery dropdown.
Item {
    id: dd
    // TODO(phase 7, section 3b): link "More" to the control center (moreRequested).

    property var batteryState
    property var powerProfileState
    signal moreRequested(int tileId)  // opens the control center on a tile

    // The buttons: only the profiles this machine offers.
    readonly property var profileEntries: {
        const all = [
            { id: Enums.PowerMode.Saver, name: "Saver" },
            { id: Enums.PowerMode.Balanced, name: "Balanced" },
            { id: Enums.PowerMode.Performance, name: "Performance" }
        ]
        const offered = dd.powerProfileState ? dd.powerProfileState.availableProfiles : []
        return all.filter(e => offered.indexOf(e.id) >= 0)
    }

    function remaining(): string {
        return dd.batteryState ? dd.batteryState.statusText() : ""
    }

    implicitWidth: 280
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 4

        // Colour only for warn and critical.
        Label {
            text: dd.batteryState ? Math.round(dd.batteryState.percent) + "%" : ""
            role: Enums.TextRole.Display
            tone: dd.batteryState ? dd.batteryState.severity : Enums.Severity.Neutral
            color: tone === Enums.Severity.Neutral ? Tokens.ink : Tokens.colorFor(tone)
        }

        Label {
            text: dd.remaining()
            color: Tokens.inkSoft
        }

        Item { width: 1; height: 12 }

        Label {
            text: "Power profile"
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }

        Row {
            id: profiles
            width: parent.width
            spacing: 4
            Repeater {
                model: dd.profileEntries
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property bool current: dd.powerProfileState && dd.powerProfileState.profile === modelData.id
                    width: (profiles.width - (dd.profileEntries.length - 1) * 4) / Math.max(1, dd.profileEntries.length)
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Tokens.surfaceAlt
                        opacity: cell.current ? 1 : (area.containsMouse ? 0.5 : 0)
                        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                    }
                    Label {
                        anchors.centerIn: parent
                        text: cell.modelData.name
                        font.weight: cell.current ? Font.DemiBold : Font.Normal
                        color: cell.current ? Tokens.ink : Tokens.inkSoft
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: dd.powerProfileState.setProfile(cell.modelData.id)
                    }
                }
            }
        }
    }
}
