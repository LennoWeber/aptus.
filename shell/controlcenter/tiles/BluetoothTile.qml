pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the BluetoothTile.
Item {
    id: tile

    property bool expanded
    property var bluetoothState

    // Looking for devices only while the list is on screen.
    onExpandedChanged: {
        if (!bluetoothState) return
        if (expanded && bluetoothState.powered) bluetoothState.startDiscovery()
        else bluetoothState.stopDiscovery()
    }

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            width: parent.width
            elide: Text.ElideRight
            text: !tile.bluetoothState ? "" : !tile.bluetoothState.powered ? "Off" : (tile.bluetoothState.connectedCount > 0 ? tile.bluetoothState.connectedCount + " connected" : "On")
            font.weight: Font.Medium
            color: !tile.bluetoothState || !tile.bluetoothState.powered ? Tokens.inkFaint : (tile.bluetoothState.connectedCount > 0 ? Tokens.ok : Tokens.ink)
        }
        ToggleSwitch {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            label: "Bluetooth"
            checked: tile.bluetoothState ? tile.bluetoothState.powered : false
            onToggled: on => tile.bluetoothState.setPowered(on)
        }
    }

    Column {
        anchors.fill: parent
        visible: tile.expanded
        spacing: 2

        ToggleSwitch {
            width: parent.width
            label: "Bluetooth"
            checked: tile.bluetoothState ? tile.bluetoothState.powered : false
            onToggled: on => {
                tile.bluetoothState.setPowered(on)
                if (on) tile.bluetoothState.startDiscovery()
            }
        }

        Label {
            visible: tile.bluetoothState && tile.bluetoothState.powered
            text: tile.bluetoothState && tile.bluetoothState.discovering ? "Devices (searching)" : "Devices"
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }

        Flickable {
            width: parent.width
            height: tile.height - 90
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list
                width: parent.width
                Repeater {
                    model: tile.bluetoothState && tile.bluetoothState.powered ? tile.bluetoothState.devices : []
                    delegate: ListRow {
                        required property var modelData
                        width: list.width
                        title: modelData.name
                        subtitle: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                        trailing: modelData.batteryPercent >= 0 ? Math.round(modelData.batteryPercent) + "%" : ""
                        selected: modelData.connected
                        dotColor: Tokens.ok
                        onClicked: {
                            if (modelData.connected) tile.bluetoothState.disconnectDevice(modelData.address)
                            else if (modelData.paired) tile.bluetoothState.connectDevice(modelData.address)
                            else tile.bluetoothState.pairDevice(modelData.address)
                        }
                    }
                }
            }
        }
    }
}
