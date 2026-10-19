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
            width: Math.min(parent.width, 460)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            ToggleSwitch {
                width: parent.width
                label: "Share this connection as a hotspot"
                checked: tile.on
                onToggled: on => tile.networkState.setHotspot(on)
            }
            Rectangle { width: parent.width; height: 1; color: Tokens.line }

            Label { visible: tile.on; text: "Network name"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Label { visible: tile.on; text: tile.networkState ? tile.networkState.hotspotSsid : ""; role: Enums.TextRole.Title }
            Label { visible: tile.on; text: "Password"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Label { visible: tile.on; text: tile.networkState ? tile.networkState.hotspotPassword : ""; role: Enums.TextRole.Mono }

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                color: tile.networkState && !tile.networkState.ethernetConnected ? Tokens.warn : Tokens.inkSoft
                text: tile.networkState && !tile.networkState.ethernetConnected
                    ? "No Ethernet connection: the hotspot uses your Wi-Fi adapter, so this laptop leaves its Wi-Fi network and has no internet to share."
                    : "The hotspot uses your Wi-Fi adapter and shares the Ethernet connection."
            }
        }
    }
}
