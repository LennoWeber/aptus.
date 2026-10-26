import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.services

// The hover panel: the quick settings that the bar's dropdowns had, in one card (volume, brightness, switches,
// music, battery), shown while the pointer rests on the island.
Item {
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
    property string expanded         // the open section: "", "wifi" or "bluetooth"; at most one
    property color ink
    property color inkSoft
    property color line
    property color fill

    signal tileRequested(int tileId)
    signal controlCenterRequested()
    signal viewRequested(int view)      // Enums.IslandView: a shortcut opens a view of the island
    signal sectionToggled(string name)  // a section was opened or closed (the island pins itself for the keyboard)

    // TODO(phase 7, Island-Blasen): The card grows with its content: the Wi-Fi and Bluetooth sections (IslandWifi, IslandBluetooth) and IslandQuickActions come into the column below.
    implicitHeight: column.implicitHeight + 20

    // Open the section name ("wifi" or "bluetooth"), or close it when it is open; the other one closes.
    function toggleSection(name: string): void {
        throw new Error("not implemented")
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
                // TODO(phase 7, Island-Blasen): A tap on the label (or a chevron) calls toggleSection("wifi"); the switch itself keeps switching Wi-Fi on and off.
                kind: "wifi"; label: "Wi-Fi"
                checked: hoverPanel.networkState ? hoverPanel.networkState.wifiEnabled : false
                ink: hoverPanel.ink; fill: hoverPanel.fill; line: hoverPanel.line
                onClicked: if (hoverPanel.networkState) hoverPanel.networkState.setWifiEnabled(!hoverPanel.networkState.wifiEnabled)
            }
            IslandToggle {
                // TODO(phase 7, Island-Blasen): Same for toggleSection("bluetooth").
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
