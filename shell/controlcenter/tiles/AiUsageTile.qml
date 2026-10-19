import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the AiUsageTile. No provider is connected yet, so it says so instead of showing made-up numbers.
Item {
    id: tile

    property bool expanded
    property var aiUsageState

    readonly property bool linked: aiUsageState ? aiUsageState.connected : false

    function amount(v: real): string {
        return v >= 1e6 ? (v / 1e6).toFixed(1) + " M" : v >= 1e3 ? (v / 1e3).toFixed(1) + " k" : Math.round(v) + ""
    }

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            width: parent.width
            elide: Text.ElideRight
            text: tile.linked ? tile.aiUsageState.provider : "No provider connected"
            font.weight: Font.Medium
            color: tile.linked ? Tokens.ink : Tokens.inkSoft
        }
        MeterBar {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 10 }
            value: tile.linked && tile.aiUsageState.limitAmount > 0 ? tile.aiUsageState.usedAmount / tile.aiUsageState.limitAmount : 0
            severity: tile.linked ? tile.aiUsageState.severity : 0
        }
        Label {
            anchors { left: parent.left; bottom: parent.bottom }
            text: tile.linked ? tile.amount(tile.aiUsageState.usedAmount) + (tile.aiUsageState.limitAmount > 0 ? " of " + tile.amount(tile.aiUsageState.limitAmount) : "") + " " + tile.aiUsageState.unit : "Comes with the AI mode"
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }
    }

    Item {
        anchors.fill: parent
        visible: tile.expanded

        Column {
            width: Math.min(parent.width, 460)
            anchors.centerIn: parent
            spacing: 8
            Label {
                width: parent.width
                text: tile.linked ? tile.aiUsageState.provider + (tile.aiUsageState.plan !== "" ? ", " + tile.aiUsageState.plan : "") : "No AI provider connected"
                role: Enums.TextRole.Title
                horizontalAlignment: Text.AlignHCenter
            }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Tokens.inkSoft
                text: tile.linked ? "" : "As soon as you add a provider in the AI mode of the launcher, your usage and the time of the next reset appear here."
            }
        }
    }
}
