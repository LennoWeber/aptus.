pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the SystemMonitorTile. Compact: three bars; expanded: cores, memory, disk, network.
Item {
    id: tile

    property bool expanded
    property var systemMonitorState

    readonly property var s: systemMonitorState

    // One line of the compact view: name, bar, value.
    component Row3: Item {
        id: r
        property string name
        property real fraction
        property int severity
        property string value
        height: 20
        Label { width: 38; anchors.verticalCenter: parent.verticalCenter; text: r.name; color: Tokens.inkSoft }
        MeterBar {
            anchors { left: parent.left; leftMargin: 44; right: parent.right; rightMargin: 52; verticalCenter: parent.verticalCenter }
            value: r.fraction
            severity: r.severity
        }
        Label {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: r.value
            tabularNumbers: true
        }
    }

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Column {
            width: parent.width
            spacing: 4
            Row3 {
                width: parent.width
                name: "CPU"
                fraction: tile.s ? tile.s.cpuPercent / 100 : 0
                severity: tile.s ? tile.s.cpuSeverity : 0
                value: tile.s ? Math.round(tile.s.cpuPercent) + "%" : ""
            }
            Row3 {
                width: parent.width
                name: "RAM"
                fraction: tile.s ? tile.s.memoryFraction : 0
                severity: tile.s ? tile.s.memorySeverity : 0
                value: tile.s ? Math.round(tile.s.memoryFraction * 100) + "%" : ""
            }
            Row3 {
                width: parent.width
                name: "Disk"
                fraction: tile.s ? tile.s.diskFraction : 0
                severity: tile.s ? tile.s.diskSeverity : 0
                value: tile.s ? Math.round(tile.s.diskFraction * 100) + "%" : ""
            }
        }
    }

    // Expanded: processor on the left; memory, storage, network and the busiest programs on the right.
    Item {
        anchors.fill: parent
        visible: tile.expanded

        Column {
            id: cpuColumn
            anchors { left: parent.left; top: parent.top; right: divider.left; rightMargin: 24 }
            spacing: 6

            Label { text: "Processor"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Item {
                width: parent.width
                height: cpuNumber.implicitHeight
                Label {
                    id: cpuNumber
                    text: tile.s ? Math.round(tile.s.cpuPercent) + "%" : ""
                    role: Enums.TextRole.Display
                    tabularNumbers: true
                }
                Column {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Label {
                        anchors.right: parent.right
                        visible: tile.s && tile.s.cpuTemperatureC > 0
                        text: tile.s ? Math.round(tile.s.cpuTemperatureC) + " °C" : ""
                        color: tile.s && tile.s.temperatureSeverity !== Enums.Severity.Neutral ? Tokens.colorFor(tile.s.temperatureSeverity) : Tokens.ink
                        tabularNumbers: true
                    }
                    Label {
                        anchors.right: parent.right
                        visible: tile.s && tile.s.cpuFrequencyMhz > 0
                        text: tile.s ? (tile.s.cpuFrequencyMhz / 1000).toFixed(2) + " GHz" : ""
                        color: Tokens.inkSoft
                        tabularNumbers: true
                    }
                }
            }
            Sparkline {
                width: parent.width
                height: 56
                values: tile.s ? tile.s.cpuHistory : []
                maximum: 100
            }
            Label { text: "Last 90 seconds"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }

            Item { width: 1; height: 4 }
            Label { text: "Cores"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Grid {
                columns: 2
                columnSpacing: 18
                rowSpacing: 7
                Repeater {
                    model: tile.s ? tile.s.cpuPerCore : []
                    delegate: Item {
                        id: coreRow
                        required property int index
                        required property real modelData
                        width: (cpuColumn.width - 18) / 2
                        height: 16
                        Label {
                            width: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: coreRow.index + 1
                            role: Enums.TextRole.Bar
                            color: Tokens.inkFaint
                        }
                        MeterBar {
                            anchors { left: parent.left; leftMargin: 24; right: parent.right; verticalCenter: parent.verticalCenter }
                            value: coreRow.modelData / 100
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }
            Row {
                visible: tile.s && tile.s.gpuPercent >= 0
                spacing: 12
                Label { text: "Graphics"; role: Enums.TextRole.Bar; color: Tokens.inkFaint; anchors.verticalCenter: parent.verticalCenter }
                MeterBar { width: 150; anchors.verticalCenter: parent.verticalCenter; value: tile.s ? Math.max(0, tile.s.gpuPercent) / 100 : 0 }
                Label { text: tile.s ? Math.round(tile.s.gpuPercent) + "%" : ""; tabularNumbers: true; anchors.verticalCenter: parent.verticalCenter }
            }
            Label {
                text: tile.s ? "Load " + tile.s.loadAverage.map(x => x.toFixed(2)).join("  ") + "   ·   Up " + tile.s.formatUptime(tile.s.uptimeSec) : ""
                color: Tokens.inkSoft
                tabularNumbers: true
            }
        }

        Rectangle {
            id: divider
            anchors { horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: -10; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Tokens.line
        }

        Column {
            anchors { left: divider.right; leftMargin: 24; top: parent.top; right: parent.right }
            spacing: 5

            // Memory
            Label { text: "Memory"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Item {
                width: parent.width
                height: memText.implicitHeight
                Label {
                    id: memText
                    text: tile.s ? tile.s.humanBytes(tile.s.memoryUsedBytes) + " of " + tile.s.humanBytes(tile.s.memoryTotalBytes) : ""
                    role: Enums.TextRole.Title
                }
                Label {
                    anchors { right: parent.right; baseline: memText.baseline }
                    text: tile.s ? Math.round(tile.s.memoryFraction * 100) + "%" : ""
                    color: Tokens.inkSoft
                    tabularNumbers: true
                }
            }
            MeterBar {
                width: parent.width
                value: tile.s ? tile.s.memoryFraction : 0
                severity: tile.s ? tile.s.memorySeverity : 0
            }
            Label {
                visible: tile.s && tile.s.swapTotalBytes > 0
                text: tile.s ? "Swap " + tile.s.humanBytes(tile.s.swapUsedBytes) + " of " + tile.s.humanBytes(tile.s.swapTotalBytes) : ""
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }

            // Storage
            Item { width: 1; height: 6 }
            Label { text: "Storage"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Repeater {
                model: tile.s ? tile.s.disks.slice(0, 2) : []
                delegate: Column {
                    id: diskRow
                    required property var modelData
                    width: parent.width
                    spacing: 3
                    Item {
                        width: parent.width
                        height: 18
                        Label { text: diskRow.modelData.mount; font.weight: Font.Medium }
                        Label {
                            anchors.right: parent.right
                            text: tile.s.humanBytes(diskRow.modelData.usedBytes) + " of " + tile.s.humanBytes(diskRow.modelData.totalBytes)
                            color: Tokens.inkSoft
                            tabularNumbers: true
                        }
                    }
                    MeterBar {
                        width: parent.width
                        value: diskRow.modelData.fraction
                        severity: diskRow.modelData.fraction > 0.95 ? Enums.Severity.Critical : diskRow.modelData.fraction > 0.88 ? Enums.Severity.Warn : Enums.Severity.Neutral
                    }
                }
            }

            // Network
            Item { width: 1; height: 6 }
            Label { text: "Network"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Item {
                width: parent.width
                height: 18
                Label { text: "Down " + (tile.s ? tile.s.humanBytes(tile.s.netDownBytesPerSec) + "/s" : ""); tabularNumbers: true }
                Label { anchors.right: parent.right; text: "Up " + (tile.s ? tile.s.humanBytes(tile.s.netUpBytesPerSec) + "/s" : ""); tabularNumbers: true }
            }
            Sparkline {
                width: parent.width
                height: 30
                values: tile.s ? tile.s.netDownHistory : []
            }

            // Busiest programs
            Item { width: 1; height: 6 }
            Label { text: "Busiest programs"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Repeater {
                model: tile.s ? tile.s.topProcesses : []
                delegate: Item {
                    id: procRow
                    required property var modelData
                    width: parent.width
                    height: 19
                    Label {
                        width: parent.width - 130
                        elide: Text.ElideRight
                        text: procRow.modelData.name
                    }
                    Label {
                        anchors { right: parent.right; rightMargin: 64 }
                        text: procRow.modelData.cpu.toFixed(1) + "%"
                        color: Tokens.inkSoft
                        tabularNumbers: true
                    }
                    Label {
                        anchors.right: parent.right
                        text: tile.s.humanBytes(procRow.modelData.memoryBytes)
                        color: Tokens.inkFaint
                        tabularNumbers: true
                    }
                }
            }
        }
    }
}
