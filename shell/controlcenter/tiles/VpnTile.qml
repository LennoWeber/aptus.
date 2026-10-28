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

    // One profile: name and state, then Auto, Remove and the connect switch.
    component ProfileRow: Item {
        id: prof
        required property var modelData
        width: parent ? parent.width : 0
        height: 52

        Column {
            anchors { left: parent.left; right: controls.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 1
            Label {
                width: parent.width
                elide: Text.ElideRight
                text: prof.modelData.name
                font.weight: Font.Medium
            }
            Label {
                width: parent.width
                elide: Text.ElideRight
                role: Enums.TextRole.Bar
                text: prof.modelData.active ? (tile.networkState.vpnIp ? "Connected, " + tile.networkState.vpnIp : "Connected") : "Off"
                color: prof.modelData.active ? Tokens.ok : Tokens.inkFaint
            }
        }
        Row {
            id: controls
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 14
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Label { anchors.verticalCenter: parent.verticalCenter; text: "Auto"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
                ToggleSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    checked: prof.modelData.autoconnect
                    onToggled: on => tile.networkState.setVpnAutoconnect(prof.modelData.id, on)
                }
            }
            ConfirmButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Remove"
                onConfirmed: tile.networkState.removeVpn(prof.modelData.id)
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Label { anchors.verticalCenter: parent.verticalCenter; text: "On"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
                ToggleSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    checked: prof.modelData.active
                    onToggled: on => tile.networkState.setVpn(prof.modelData.id, on)
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: tile.expanded

        Column {
            width: Math.min(parent.width, 640)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Label {
                text: "VPN profiles"
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Repeater {
                model: tile.profiles
                delegate: ProfileRow {}
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
