pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the AiUsageTile: Claude's 5 hour and 7 day windows. Without a readable usage file it says so.
Item {
    id: tile

    property bool expanded
    property var aiUsageState

    readonly property bool linked: aiUsageState ? aiUsageState.connected : false

    function percent(fraction: real): string {
        return Math.round(fraction * 100) + "%"
    }

    // One window: name, bar, percent and the time to the reset.
    component Window: Item {
        id: win
        property string title
        property real fraction
        property string resetText
        implicitHeight: 46
        Label { text: win.title; font.weight: Font.Medium }
        Label { anchors.right: parent.right; text: tile.percent(win.fraction); tabularNumbers: true; font.weight: Font.Medium }
        MeterBar {
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 22 }
            value: win.fraction
            severity: tile.aiUsageState.severityOf(win.fraction)
        }
        Label {
            anchors { left: parent.left; bottom: parent.bottom }
            text: win.resetText !== "" ? "Resets in " + win.resetText : ""
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }
    }

    // Compact view: the tighter of the two windows, the other one as text.
    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            width: parent.width
            elide: Text.ElideRight
            text: tile.linked ? "Claude " + tile.percent(tile.aiUsageState.fiveHour) + " · 5 h" : "No usage data"
            font.weight: Font.Medium
            color: tile.linked ? Tokens.ink : Tokens.inkSoft
        }
        MeterBar {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 10 }
            value: tile.linked ? tile.aiUsageState.fiveHour : 0
            severity: tile.linked ? tile.aiUsageState.severityOf(tile.aiUsageState.fiveHour) : 0
        }
        Label {
            anchors { left: parent.left; bottom: parent.bottom }
            text: tile.linked ? "7 d " + tile.percent(tile.aiUsageState.sevenDay) + (tile.aiUsageState.stale ? " · old" : "") : "~/.claude/usage-cache.json"
            role: Enums.TextRole.Bar
            color: tile.linked && tile.aiUsageState.stale ? Tokens.warn : Tokens.inkFaint
        }
    }

    Item {
        anchors.fill: parent
        visible: tile.expanded

        Column {
            width: Math.min(parent.width, 460)
            anchors.centerIn: parent
            spacing: 14

            Label {
                width: parent.width
                visible: !tile.linked
                text: "No usage data"
                role: Enums.TextRole.Title
                horizontalAlignment: Text.AlignHCenter
            }
            Label {
                width: parent.width
                visible: !tile.linked
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Tokens.inkSoft
                text: "aptus reads Claude's usage from ~/.claude/usage-cache.json, which Claude Code keeps up to date. The file is missing or empty here."
            }

            Label { visible: tile.linked; width: parent.width; text: "Claude usage"; role: Enums.TextRole.Title }
            Window {
                visible: tile.linked
                width: parent.width
                title: "5 hours"
                fraction: tile.linked ? tile.aiUsageState.fiveHour : 0
                resetText: tile.linked ? tile.aiUsageState.untilText(tile.aiUsageState.fiveHourResetsAt) : ""
            }
            Window {
                visible: tile.linked
                width: parent.width
                title: "7 days"
                fraction: tile.linked ? tile.aiUsageState.sevenDay : 0
                resetText: tile.linked ? tile.aiUsageState.untilText(tile.aiUsageState.sevenDayResetsAt) : ""
            }

            // Where the 7 day usage went.
            Column {
                visible: tile.linked && tile.aiUsageState.breakdown.length > 0
                width: parent.width
                spacing: 4
                Label { text: "This week by product"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
                Repeater {
                    model: tile.linked ? tile.aiUsageState.breakdown : []
                    delegate: Item {
                        id: part
                        required property var modelData
                        width: parent.width
                        height: 20
                        Label { text: part.modelData.name; color: Tokens.inkSoft }
                        Label { anchors.right: parent.right; text: part.modelData.percent + "%"; tabularNumbers: true; color: Tokens.inkSoft }
                    }
                }
            }

            Label {
                visible: tile.linked
                width: parent.width
                text: "Updated " + (tile.linked ? tile.aiUsageState.ageText() : "") + (tile.linked && tile.aiUsageState.stale ? ". The numbers move when Claude Code runs." : "")
                role: Enums.TextRole.Bar
                color: tile.linked && tile.aiUsageState.stale ? Tokens.warn : Tokens.inkFaint
                wrapMode: Text.Wrap
            }
            Label {
                visible: !!tile.aiUsageState && tile.aiUsageState.liveError !== ""
                width: parent.width
                text: tile.aiUsageState ? tile.aiUsageState.liveErrorText() : ""
                role: Enums.TextRole.Bar
                color: Tokens.warn
                wrapMode: Text.Wrap
            }
        }
    }
}
