pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the PowerProfileTile (battery and power profile).
Item {
    id: tile

    property bool expanded
    property var powerProfileState
    property var batteryState

    readonly property var profiles: [
        { id: Enums.PowerMode.Saver, name: "Saver", text: "Longer battery life, cooler and quieter" },
        { id: Enums.PowerMode.Balanced, name: "Balanced", text: "For everyday use" },
        { id: Enums.PowerMode.Performance, name: "Performance", text: "Full speed, more heat and noise" }
    ]
    readonly property var offered: powerProfileState ? profiles.filter(p => powerProfileState.availableProfiles.indexOf(p.id) >= 0) : []

    // Colour says what the profile costs: saver = green, balanced = neutral, performance = amber.
    function colorOf(profile: int): color {
        return profile === Enums.PowerMode.Saver ? Tokens.ok : (profile === Enums.PowerMode.Performance ? Tokens.warn : Tokens.inkSoft)
    }

    function nameOf(profile: int): string {
        const p = profiles.find(x => x.id === profile)
        return p ? p.name : "Balanced"
    }

    function statusText(): string {
        const b = tile.batteryState
        if (!b || !b.present) return ""
        if (b.fullyCharged) return "Fully charged"
        if (b.timeRemainingMin < 0) return b.charging ? "Charging" : (b.discharging ? "On battery" : "Plugged in")
        const h = Math.floor(b.timeRemainingMin / 60)
        const t = (h > 0 ? h + " h " : "") + (b.timeRemainingMin % 60) + " min"
        return b.charging ? t + " until full" : t + " left"
    }

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            text: tile.batteryState && tile.batteryState.present ? Math.round(tile.batteryState.percent) + "%" : "No battery"
            role: Enums.TextRole.Title
            tone: tile.batteryState ? tile.batteryState.severity : Enums.Severity.Neutral
            color: tone === Enums.Severity.Neutral ? Tokens.ink : Tokens.colorFor(tone)
        }
        Label {
            anchors { left: parent.left; bottom: parent.bottom }
            text: tile.powerProfileState ? tile.nameOf(tile.powerProfileState.profile) : ""
            font.weight: tile.powerProfileState && tile.powerProfileState.profile !== Enums.PowerMode.Balanced ? Font.DemiBold : Font.Normal
            color: tile.powerProfileState ? tile.colorOf(tile.powerProfileState.profile) : Tokens.inkSoft
        }
    }

    // Expanded: the battery on the left, three large profile cards on the right.
    Item {
        anchors.fill: parent
        visible: tile.expanded

        Column {
            id: left
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.width * 0.38
            spacing: 6

            Label {
                text: "Battery"
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Label {
                text: tile.batteryState && tile.batteryState.present ? Math.round(tile.batteryState.percent) + "%" : "No battery"
                role: Enums.TextRole.Display
                tone: tile.batteryState ? tile.batteryState.severity : Enums.Severity.Neutral
                color: tone === Enums.Severity.Neutral ? Tokens.ink : Tokens.colorFor(tone)
            }
            Label {
                text: tile.statusText()
                color: Tokens.inkSoft
            }
            Item { width: 1; height: 14 }
            // The battery as a wide bar: outline, fill by charge, colour only for warn and critical.
            Rectangle {
                width: parent.width
                height: 28
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: Tokens.line
                visible: tile.batteryState ? tile.batteryState.present : false

                Rectangle {
                    x: 3
                    y: 3
                    height: parent.height - 6
                    width: Math.max(4, (parent.width - 6) * (tile.batteryState ? tile.batteryState.percent : 0) / 100)
                    radius: 5
                    color: tile.batteryState && tile.batteryState.severity !== Enums.Severity.Neutral ? Tokens.colorFor(tile.batteryState.severity) : (tile.batteryState && tile.batteryState.charging ? Tokens.ok : Tokens.ink)
                    Behavior on width { NumberAnimation { duration: Tokens.durSlow } }
                }
            }
        }

        Rectangle {
            id: divider
            anchors { left: left.right; leftMargin: 24; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Tokens.line
        }

        Column {
            anchors { left: divider.right; leftMargin: 24; top: parent.top; right: parent.right }
            spacing: 8

            Label {
                text: "Power profile"
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }

            Repeater {
                model: tile.offered
                delegate: Item {
                    id: card
                    required property var modelData
                    readonly property bool current: tile.powerProfileState && tile.powerProfileState.profile === modelData.id
                    width: parent.width
                    height: 92

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: card.current ? Tokens.surfaceAlt : "transparent"
                        border.width: 1
                        border.color: card.current ? tile.colorOf(card.modelData.id) : Tokens.line
                        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
                    }
                    Rectangle {
                        visible: card.current
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: tile.colorOf(card.modelData.id)
                    }
                    Column {
                        anchors { left: parent.left; leftMargin: 40; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Label {
                            text: card.modelData.name
                            role: Enums.TextRole.Title
                            color: card.current ? tile.colorOf(card.modelData.id) : Tokens.ink
                        }
                        Label {
                            width: parent.width
                            elide: Text.ElideRight
                            text: card.modelData.text
                            color: Tokens.inkSoft
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: tile.powerProfileState.setProfile(card.modelData.id)
                    }
                }
            }
        }
    }
}
