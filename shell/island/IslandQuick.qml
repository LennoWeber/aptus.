pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.services

// The quick settings card: the quick settings that the bar's dropdowns had, in one card (volume, brightness, switches,
// music, battery), shown under the opened home card.
FocusScope {
    // TODO(phase 7): rename the id to quick (every `hoverPanel.` in this file) and the error texts "IslandHover" to "IslandQuick".
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
    property string expanded         // the open section: "", "wifi", "bluetooth" or "sound"; at most one
    property color ink
    property color inkSoft
    property color line
    property color fill

    signal tileRequested(int tileId)
    signal controlCenterRequested()
    // At most one section is open, and only a known one.
    onExpandedChanged: if (expanded !== "" && expanded !== "wifi" && expanded !== "bluetooth" && expanded !== "sound") throw new Error("invariant: IslandHover: unknown section")

    // TODO(phase 7): fix the comment: Esc in the opened island (there is no pinned card).
    signal closeRequested()             // Esc on a pinned card
    signal viewRequested(int view)      // Enums.IslandView: a shortcut opens a view of the island
    signal sectionToggled(string name)  // a section was opened or closed (the island pins itself for the keyboard)

    Keys.onEscapePressed: closeRequested()

    implicitHeight: column.implicitHeight + 20

    // Text on the right of the header row of a section (the network, the number of devices, the output).
    function sectionValue(name: string): string {
        if (name !== "wifi" && name !== "bluetooth" && name !== "sound") throw new Error("invariant: IslandHover.sectionValue: unknown section")
        if (name === "wifi") return networkState && networkState.wifiEnabled ? (networkState.ssid || "Not connected") : "Off"
        if (name === "bluetooth") return bluetoothState && bluetoothState.powered ? (bluetoothState.connectedCount > 0 ? bluetoothState.connectedCount + " connected" : "On") : "Off"
        return audioState ? (audioState.outputName || "No output") : ""
    }

    // A header row of a section: symbol, title, the value, a chevron.
    component SectionHeader: Item {
        id: hdr
        property string name
        property string glyph
        property string title
        width: parent.width
        height: 38
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: hoverPanel.ink
            opacity: hdrMouse.pressed ? 0.10 : hoverPanel.expanded === hdr.name ? 0.06 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
        }
        StatusGlyph { id: hdrGlyph; anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter } kind: hdr.glyph; color: hoverPanel.ink }
        Label { id: hdrTitle; anchors { left: hdrGlyph.right; leftMargin: 10; verticalCenter: parent.verticalCenter } text: hdr.title; role: Enums.TextRole.Bar; color: hoverPanel.ink; font.weight: Font.Medium }
        Label {
            anchors { left: hdrTitle.right; leftMargin: 12; right: chevron.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            horizontalAlignment: Text.AlignRight
            text: hoverPanel.sectionValue(hdr.name)
            role: Enums.TextRole.Bar
            elide: Text.ElideRight
            color: hoverPanel.inkSoft
        }
        Label { id: chevron; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: hoverPanel.expanded === hdr.name ? "⌃" : "⌄"; color: hoverPanel.inkSoft }
        MouseArea { id: hdrMouse; anchors.fill: parent; onClicked: hoverPanel.toggleSection(hdr.name) }
    }

    // Open the section name ("wifi" or "bluetooth"), or close it when it is open; the other one closes.
    function toggleSection(name: string): void {
        if (name !== "wifi" && name !== "bluetooth" && name !== "sound") throw new Error("invariant: IslandHover.toggleSection: unknown section")
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

        // Header rows open the sections (big enough for touch).
        SectionHeader { name: "wifi"; glyph: "wifi"; title: "Wi-Fi" }
        IslandWifi {
            visible: hoverPanel.expanded === "wifi"
            width: parent.width
            height: visible ? implicitHeight : 0
            networkState: hoverPanel.networkState
            shown: hoverPanel.expanded === "wifi"
            ink: hoverPanel.ink; inkSoft: hoverPanel.inkSoft; line: hoverPanel.line; fill: hoverPanel.fill
            onCloseRequested: hoverPanel.closeRequested()
        }
        SectionHeader { name: "bluetooth"; glyph: "bluetooth"; title: "Bluetooth" }
        IslandBluetooth {
            visible: hoverPanel.expanded === "bluetooth"
            width: parent.width
            height: visible ? implicitHeight : 0
            bluetoothState: hoverPanel.bluetoothState
            shown: hoverPanel.expanded === "bluetooth"
            ink: hoverPanel.ink; inkSoft: hoverPanel.inkSoft; line: hoverPanel.line; fill: hoverPanel.fill
            onCloseRequested: hoverPanel.closeRequested()
        }
        SectionHeader { name: "sound"; glyph: "volume"; title: "Sound" }
        IslandSound {
            visible: hoverPanel.expanded === "sound"
            width: parent.width
            height: visible ? implicitHeight : 0
            audioState: hoverPanel.audioState
            shown: hoverPanel.expanded === "sound"
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
