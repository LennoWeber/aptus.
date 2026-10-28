import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the HotspotTile. Compact: state; expanded: switch with name and password.
Item {
    id: tile

    property bool expanded
    property var networkState

    readonly property bool on: networkState ? networkState.hotspotActive : false
    property string draftSsid
    property string draftPassword
    property bool dirty              // the drafts differ from what NetworkManager has
    readonly property int ssidBytes: unescape(encodeURIComponent(draftSsid)).length
    readonly property bool valid: ssidBytes >= 1 && ssidBytes <= 32 && draftPassword.length >= 8 && draftPassword.length <= 63

    // The drafts start from what NetworkManager has when the view opens, and follow it while nothing was edited.
    function loadDrafts(): void {
        draftSsid = networkState.hotspotSsid || "shell hotspot"
        draftPassword = networkState.hotspotPassword
        dirty = false
    }
    onExpandedChanged: if (expanded && networkState) loadDrafts()
    Connections {
        target: tile.networkState
        enabled: tile.expanded && !tile.dirty
        function onHotspotSsidChanged() { tile.loadDrafts() }
        function onHotspotPasswordChanged() { tile.loadDrafts() }
    }

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        StatusGlyph {
            kind: "hotspot"
            width: 24
            height: 24
            color: tile.on ? Tokens.ok : Tokens.inkSoft
        }
        Label {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            elide: Text.ElideRight
            text: tile.on ? (tile.networkState.hotspotSsid || "On") : "Off"
            font.weight: tile.on ? Font.DemiBold : Font.Normal
            color: tile.on ? Tokens.ok : Tokens.inkSoft
        }
    }

    Item {
        anchors.fill: parent
        visible: tile.expanded

        Column {
            id: left
            anchors { left: parent.left; top: parent.top }
            width: Math.min(360, parent.width * 0.42)
            spacing: 8

            ToggleSwitch {
                width: parent.width
                label: "Share this connection"
                checked: tile.on
                onToggled: on => tile.networkState.setHotspot(on)
            }
            Item { width: 1; height: 6 }
            Label {
                text: tile.on ? "Running" : "Off"
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Label {
                width: parent.width
                elide: Text.ElideRight
                text: tile.on ? tile.networkState.hotspotSsid : "Not sharing"
                role: Enums.TextRole.Title
                color: tile.on ? Tokens.ok : Tokens.ink
            }
            Label {
                visible: tile.on
                text: tile.networkState ? (tile.networkState.hotspotClients === 1 ? "1 device connected" : tile.networkState.hotspotClients + " devices connected") : ""
                color: Tokens.inkSoft
            }
            Item { width: 1; height: 6 }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                color: tile.networkState && !tile.networkState.ethernetConnected ? Tokens.warn : Tokens.inkSoft
                text: tile.networkState && !tile.networkState.ethernetConnected
                    ? "No Ethernet connection: the hotspot uses your Wi-Fi adapter, so this laptop leaves its Wi-Fi network and has no internet to share."
                    : "The hotspot uses your Wi-Fi adapter and shares the Ethernet connection."
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
            spacing: 6

            Label { text: "Network name"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            InputField {
                width: Math.min(parent.width, 420)
                height: 40
                text: tile.draftSsid
                placeholder: "Network name"
                onTextChanged: if (text !== tile.draftSsid) { tile.draftSsid = text; tile.dirty = true }
            }
            Item { width: 1; height: 4 }
            Label { text: "Password"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            InputField {
                width: Math.min(parent.width, 420)
                height: 40
                text: tile.draftPassword
                placeholder: "8 to 63 characters"
                onTextChanged: if (text !== tile.draftPassword) { tile.draftPassword = text; tile.dirty = true }
            }
            Label {
                visible: tile.dirty && !tile.valid
                width: Math.min(parent.width, 420)
                wrapMode: Text.Wrap
                color: Tokens.warn
                text: tile.ssidBytes < 1 || tile.ssidBytes > 32 ? "The name needs 1 to 32 characters." : "The password needs 8 to 63 characters."
            }
            Item { width: 1; height: 6 }
            Row {
                spacing: 8
                ActionButton {
                    text: tile.on ? "Save and restart" : "Save"
                    primary: true
                    active: tile.dirty && tile.valid
                    onClicked: {
                        tile.networkState.configureHotspot(tile.draftSsid, tile.draftPassword)
                        tile.dirty = false
                    }
                }
                ActionButton {
                    text: "Revert"
                    active: tile.dirty
                    onClicked: tile.loadDrafts()
                }
            }
        }
    }
}
