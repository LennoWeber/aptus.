pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the VpnTile. Compact: state; expanded: the VPN profiles of NetworkManager.
Item {
    id: tile

    property bool expanded
    property var networkState

    readonly property bool on: networkState ? networkState.vpnActive : false
    readonly property var profiles: networkState && networkState.vpnProfiles ? networkState.vpnProfiles : []

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        StatusGlyph {
            kind: "shield"
            width: 24
            height: 24
            color: tile.on ? Tokens.ok : Tokens.inkSoft
        }
        Label {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            elide: Text.ElideRight
            text: tile.on ? tile.networkState.vpnName : (tile.profiles.length > 0 ? "Off" : "None set up")
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
            spacing: 6

            Label {
                text: "VPN profiles"
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Repeater {
                model: tile.profiles
                delegate: ToggleSwitch {
                    required property var modelData
                    width: parent.width
                    label: modelData.name
                    checked: modelData.active
                    onToggled: on => tile.networkState.setVpn(modelData.id, on)
                }
            }
            Label {
                visible: tile.profiles.length === 0
                width: parent.width
                wrapMode: Text.Wrap
                color: Tokens.inkSoft
                text: "No VPN profile found in NetworkManager. Import one (for example with nmcli connection import type wireguard file your.conf) and it shows up here."
            }
        }
    }
}
