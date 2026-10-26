import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.services

// The hover panel: the quick settings that the bar's dropdowns had, in one card (volume, brightness, switches,
// music, battery), shown while the pointer rests on the island.
FocusScope {
    id: hoverPanel

    property var appSettings
    property var audioState
    property var displayState
    property var networkState
    property var bluetoothState
    property var batteryState
    property var nightLightState
    property var caffeineState
    property var focusState
    property var mediaState
    property var powerProfileState
    property var audioState
    property string expanded         // the open section: "", "wifi", "bluetooth" or "sound"; at most one
    property color ink
    property color inkSoft
    property color line
    property color fill

    signal tileRequested(int tileId)
    signal controlCenterRequested()
    // At most one section is open, and only a known one.
    onExpandedChanged: if (expanded !== "" && expanded !== "wifi" && expanded !== "bluetooth") throw new Error("invariant: IslandHover: unknown section")

    signal closeRequested()             // Esc on a pinned card
    signal viewRequested(int view)      // Enums.IslandView: a shortcut opens a view of the island
    signal sectionToggled(string name)  // a section was opened or closed (the island pins itself for the keyboard)

    Keys.onEscapePressed: closeRequested()

    implicitHeight: column.implicitHeight + 20

    // Text on the right of the header row of a section (the network, the number of devices, the output).
    function sectionValue(name: string): string {
        throw new Error("not implemented")
    }

    // Open the section name ("wifi" or "bluetooth"), or close it when it is open; the other one closes.
    function toggleSection(name: string): void {
        if (name !== "wifi" && name !== "bluetooth") throw new Error("invariant: IslandHover.toggleSection: unknown section")
        expanded = expanded === name ? "" : name
        sectionToggled(expanded)
    }

    Column {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; topMargin: 10 }
        spacing: 4

        IslandSlider {
            width: parent.width
            iconName: "volume"
            ink: hoverPanel.ink
            line: hoverPanel.line
            value: hoverPanel.audioState ? (hoverPanel.audioState.muted ? 0 : hoverPanel.audioState.volume) : 0
            onMoved: v => { if (hoverPanel.audioState) { if (hoverPanel.audioState.muted) hoverPanel.audioState.setMuted(false); hoverPanel.audioState.setVolume(v) } }
            onIconClicked: if (hoverPanel.audioState) hoverPanel.audioState.toggleMute()
        }
        IslandSlider {
            width: parent.width
            iconName: "sun"
            ink: hoverPanel.ink
            line: hoverPanel.line
            value: hoverPanel.displayState ? hoverPanel.displayState.brightness : 0
            onMoved: v => { if (hoverPanel.displayState) hoverPanel.displayState.setBrightness(v) }
        }

        Item { width: 1; height: 4 }

        Row {
            width: parent.width
            spacing: (width - 5 * 62) / 4
            IslandToggle {
                kind: "wifi"; label: "Wi-Fi"
                checked: hoverPanel.networkState ? hoverPanel.networkState.wifiEnabled : false
                ink: hoverPanel.ink; fill: hoverPanel.fill; line: hoverPanel.line
                onClicked: if (hoverPanel.networkState) hoverPanel.networkState.setWifiEnabled(!hoverPanel.networkState.wifiEnabled)
            }
            IslandToggle {
                kind: "bluetooth"; label: "Bluetooth"
                checked: hoverPanel.bluetoothState ? hoverPanel.bluetoothState.powered : false
                ink: hoverPanel.ink; fill: hoverPanel.fill; line: hoverPanel.line
                onClicked: if (hoverPanel.bluetoothState) hoverPanel.bluetoothState.setPowered(!hoverPanel.bluetoothState.powered)
            }
            IslandToggle {
                kind: "moon"; label: "Night"
                checked: hoverPanel.nightLightState ? hoverPanel.nightLightState.enabled : false
                ink: hoverPanel.ink; fill: hoverPanel.fill; line: hoverPanel.line
                onClicked: if (hoverPanel.nightLightState) hoverPanel.nightLightState.setEnabled(!hoverPanel.nightLightState.enabled)
            }
            IslandToggle {
                kind: "cup"; label: "Caffeine"
                checked: hoverPanel.caffeineState ? hoverPanel.caffeineState.active : false
                ink: hoverPanel.ink; fill: hoverPanel.fill; line: hoverPanel.line
                onClicked: if (hoverPanel.caffeineState) hoverPanel.caffeineState.toggle()
            }
            IslandToggle {
                kind: "focus"; label: "Focus"
                checked: hoverPanel.focusState ? hoverPanel.focusState.active : false
                ink: hoverPanel.ink; fill: hoverPanel.fill; line: hoverPanel.line
                onClicked: if (hoverPanel.focusState) hoverPanel.focusState.toggle()
            }
        }

        // Header rows open the sections (34 px high: big enough for touch, which the toggle labels are not).
        Item {
            width: parent.width
            height: 34
            Label {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                // TODO(phase 7, Island-Galerie): Header row: StatusGlyph on the left, title, the value from sectionValue(name) on the right, chevron; same look for Bluetooth and the new Sound row.
                text: "Wi-Fi  " + (hoverPanel.networkState && hoverPanel.networkState.wifiEnabled ? (hoverPanel.networkState.ssid || "not connected") : "off")
                role: Enums.TextRole.Bar
                color: hoverPanel.ink
            }
            Label { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: hoverPanel.expanded === "wifi" ? "⌃" : "⌄"; color: hoverPanel.inkSoft }
            MouseArea { anchors.fill: parent; onClicked: hoverPanel.toggleSection("wifi") }
        }
        IslandWifi {
            visible: hoverPanel.expanded === "wifi"
            width: parent.width
            height: visible ? implicitHeight : 0
            networkState: hoverPanel.networkState
            shown: hoverPanel.expanded === "wifi"
            ink: hoverPanel.ink; inkSoft: hoverPanel.inkSoft; line: hoverPanel.line; fill: hoverPanel.fill
            onCloseRequested: hoverPanel.closeRequested()
        }
        Item {
            width: parent.width
            height: 34
            Label {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Bluetooth  " + (hoverPanel.bluetoothState && hoverPanel.bluetoothState.powered ? (hoverPanel.bluetoothState.connectedCount + " connected") : "off")
                role: Enums.TextRole.Bar
                color: hoverPanel.ink
            }
            Label { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: hoverPanel.expanded === "bluetooth" ? "⌃" : "⌄"; color: hoverPanel.inkSoft }
            MouseArea { anchors.fill: parent; onClicked: hoverPanel.toggleSection("bluetooth") }
        }
        // TODO(phase 7, Island-Galerie): Under the Bluetooth section: a Sound header row and IslandSound (audioState, shown, closeRequested), then the profile and the shortcuts.
        IslandBluetooth {
            visible: hoverPanel.expanded === "bluetooth"
            width: parent.width
            height: visible ? implicitHeight : 0
            bluetoothState: hoverPanel.bluetoothState
            shown: hoverPanel.expanded === "bluetooth"
            ink: hoverPanel.ink; inkSoft: hoverPanel.inkSoft; line: hoverPanel.line; fill: hoverPanel.fill
            onCloseRequested: hoverPanel.closeRequested()
        }

        Rectangle { width: parent.width; height: 1; color: hoverPanel.line }

        IslandQuickActions {
            width: parent.width
            powerProfileState: hoverPanel.powerProfileState
            ink: hoverPanel.ink; inkSoft: hoverPanel.inkSoft; line: hoverPanel.line; fill: hoverPanel.fill
            onViewRequested: v => hoverPanel.viewRequested(v)
        }

        Rectangle { visible: hoverPanel.mediaState && hoverPanel.mediaState.available; width: parent.width; height: 1; color: hoverPanel.line }

        IslandMedia {
            visible: hoverPanel.mediaState && hoverPanel.mediaState.available
            width: parent.width
            height: visible ? implicitHeight : 0
            mediaState: hoverPanel.mediaState
            ink: hoverPanel.ink
            inkSoft: hoverPanel.inkSoft
            line: hoverPanel.line
        }

        Rectangle { width: parent.width; height: 1; color: hoverPanel.line }

        Item {
            width: parent.width
            height: 32
            Label {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                visible: hoverPanel.batteryState && hoverPanel.batteryState.present
                text: hoverPanel.batteryState ? hoverPanel.batteryState.statusText() : ""
                role: Enums.TextRole.Bar
                color: hoverPanel.inkSoft
                tabularNumbers: true
            }
            Label {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "Control center"
                role: Enums.TextRole.Bar
                color: hoverPanel.ink
                font.weight: Font.Medium
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: hoverPanel.controlCenterRequested() }
            }
        }
    }
}
