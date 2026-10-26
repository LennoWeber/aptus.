pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// The quick settings card: the quick settings that the bar's dropdowns had, in one card (volume, brightness, switches,
// music, battery), shown under the opened home card.
FocusScope {
    id: quick

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
    onExpandedChanged: if (expanded !== "" && expanded !== "wifi" && expanded !== "bluetooth" && expanded !== "sound") throw new Error("invariant: IslandQuick: unknown section")

    signal closeRequested()             // Esc in the opened island
    signal viewRequested(int view)      // Enums.IslandView: a shortcut opens a view of the island
    signal sectionToggled(string name)  // a section was opened or closed (the island pins itself for the keyboard)

    Keys.onEscapePressed: closeRequested()

    implicitHeight: column.implicitHeight + 20

    // Text on the right of the header row of a section (the network, the number of devices, the output).
    function sectionValue(name: string): string {
        if (name !== "wifi" && name !== "bluetooth" && name !== "sound") throw new Error("invariant: IslandQuick.sectionValue: unknown section")
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
            color: quick.ink
            opacity: hdrMouse.pressed ? 0.10 : quick.expanded === hdr.name ? 0.06 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
        }
        StatusGlyph { id: hdrGlyph; anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter } kind: hdr.glyph; color: quick.ink }
        Label { id: hdrTitle; anchors { left: hdrGlyph.right; leftMargin: 10; verticalCenter: parent.verticalCenter } text: hdr.title; role: Enums.TextRole.Bar; color: quick.ink; font.weight: Font.Medium }
        Label {
            anchors { left: hdrTitle.right; leftMargin: 12; right: chevron.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            horizontalAlignment: Text.AlignRight
            text: quick.sectionValue(hdr.name)
            role: Enums.TextRole.Bar
            elide: Text.ElideRight
            color: quick.inkSoft
        }
        Label { id: chevron; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: quick.expanded === hdr.name ? "⌃" : "⌄"; color: quick.inkSoft }
        MouseArea { id: hdrMouse; anchors.fill: parent; onClicked: quick.toggleSection(hdr.name) }
    }

    // Open the section name ("wifi" or "bluetooth"), or close it when it is open; the other one closes.
    function toggleSection(name: string): void {
        if (name !== "wifi" && name !== "bluetooth" && name !== "sound") throw new Error("invariant: IslandQuick.toggleSection: unknown section")
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
            ink: quick.ink
            line: quick.line
            value: quick.audioState ? (quick.audioState.muted ? 0 : quick.audioState.volume) : 0
            onMoved: v => { if (quick.audioState) { if (quick.audioState.muted) quick.audioState.setMuted(false); quick.audioState.setVolume(v) } }
            onIconClicked: if (quick.audioState) quick.audioState.toggleMute()
        }
        IslandSlider {
            width: parent.width
            iconName: "sun"
            ink: quick.ink
            line: quick.line
            value: quick.displayState ? quick.displayState.brightness : 0
            onMoved: v => { if (quick.displayState) quick.displayState.setBrightness(v) }
        }

        Item { width: 1; height: 4 }

        Row {
            width: parent.width
            spacing: (width - 5 * 62) / 4
            IslandToggle {
                kind: "wifi"; label: "Wi-Fi"
                checked: quick.networkState ? quick.networkState.wifiEnabled : false
                ink: quick.ink; fill: quick.fill; line: quick.line
                onClicked: if (quick.networkState) quick.networkState.setWifiEnabled(!quick.networkState.wifiEnabled)
            }
            IslandToggle {
                kind: "bluetooth"; label: "Bluetooth"
                checked: quick.bluetoothState ? quick.bluetoothState.powered : false
                ink: quick.ink; fill: quick.fill; line: quick.line
                onClicked: if (quick.bluetoothState) quick.bluetoothState.setPowered(!quick.bluetoothState.powered)
            }
            IslandToggle {
                kind: "moon"; label: "Night"
                checked: quick.nightLightState ? quick.nightLightState.enabled : false
                ink: quick.ink; fill: quick.fill; line: quick.line
                onClicked: if (quick.nightLightState) quick.nightLightState.setEnabled(!quick.nightLightState.enabled)
            }
            IslandToggle {
                kind: "cup"; label: "Caffeine"
                checked: quick.caffeineState ? quick.caffeineState.active : false
                ink: quick.ink; fill: quick.fill; line: quick.line
                onClicked: if (quick.caffeineState) quick.caffeineState.toggle()
            }
            IslandToggle {
                kind: "focus"; label: "Focus"
                checked: quick.focusState ? quick.focusState.active : false
                ink: quick.ink; fill: quick.fill; line: quick.line
                onClicked: if (quick.focusState) quick.focusState.toggle()
            }
        }

        // Header rows open the sections (big enough for touch).
        SectionHeader { name: "wifi"; glyph: "wifi"; title: "Wi-Fi" }
        IslandWifi {
            visible: quick.expanded === "wifi"
            width: parent.width
            height: visible ? implicitHeight : 0
            networkState: quick.networkState
            shown: quick.expanded === "wifi"
            ink: quick.ink; inkSoft: quick.inkSoft; line: quick.line; fill: quick.fill
            onCloseRequested: quick.closeRequested()
        }
        SectionHeader { name: "bluetooth"; glyph: "bluetooth"; title: "Bluetooth" }
        IslandBluetooth {
            visible: quick.expanded === "bluetooth"
            width: parent.width
            height: visible ? implicitHeight : 0
            bluetoothState: quick.bluetoothState
            shown: quick.expanded === "bluetooth"
            ink: quick.ink; inkSoft: quick.inkSoft; line: quick.line; fill: quick.fill
            onCloseRequested: quick.closeRequested()
        }
        SectionHeader { name: "sound"; glyph: "volume"; title: "Sound" }
        IslandSound {
            visible: quick.expanded === "sound"
            width: parent.width
            height: visible ? implicitHeight : 0
            audioState: quick.audioState
            shown: quick.expanded === "sound"
            ink: quick.ink; inkSoft: quick.inkSoft; line: quick.line; fill: quick.fill
            onCloseRequested: quick.closeRequested()
        }

        Rectangle { width: parent.width; height: 1; color: quick.line }

        IslandQuickActions {
            width: parent.width
            powerProfileState: quick.powerProfileState
            ink: quick.ink; inkSoft: quick.inkSoft; line: quick.line; fill: quick.fill
            onViewRequested: v => quick.viewRequested(v)
        }

        Rectangle { visible: quick.mediaState && quick.mediaState.available; width: parent.width; height: 1; color: quick.line }

        IslandMedia {
            visible: quick.mediaState && quick.mediaState.available
            width: parent.width
            height: visible ? implicitHeight : 0
            mediaState: quick.mediaState
            ink: quick.ink
            inkSoft: quick.inkSoft
            line: quick.line
        }

        Rectangle { width: parent.width; height: 1; color: quick.line }

        Item {
            width: parent.width
            height: 32
            Label {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                visible: quick.batteryState && quick.batteryState.present
                text: quick.batteryState ? quick.batteryState.statusText() : ""
                role: Enums.TextRole.Bar
                color: quick.inkSoft
                tabularNumbers: true
            }
            Label {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "Control center"
                role: Enums.TextRole.Bar
                color: quick.ink
                font.weight: Font.Medium
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: quick.controlCenterRequested() }
            }
        }
    }
}
