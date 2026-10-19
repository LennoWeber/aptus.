pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the bluetooth dropdown: power switch, known devices with battery, a link to the control center.
Item {
    id: dd

    property var bluetoothState
    property bool shown  // true while the dropdown is on screen: searching only then
    signal moreRequested(int tileId)  // opens the control center on a tile

    readonly property bool on: bluetoothState ? bluetoothState.powered : false
    // Connected and paired devices first; searching adds the rest.
    readonly property var list: {
        if (!bluetoothState || !on) return []
        const all = Array.from(bluetoothState.devices)
        return all.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)).slice(0, 6)
    }

    onShownChanged: {
        if (!bluetoothState) return
        if (shown && on) bluetoothState.startDiscovery()
        else bluetoothState.stopDiscovery()
    }
    Component.onDestruction: if (bluetoothState) bluetoothState.stopDiscovery()

    implicitWidth: 320
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 2

        ToggleSwitch {
            width: parent.width
            label: "Bluetooth"
            checked: dd.on
            onToggled: on => {
                dd.bluetoothState.setPowered(on)
                if (on) dd.bluetoothState.startDiscovery()
            }
        }

        Label {
            visible: dd.on
            text: dd.bluetoothState && dd.bluetoothState.discovering ? "Devices (searching)" : "Devices"
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }

        Repeater {
            model: dd.list
            delegate: ListRow {
                required property var modelData
                width: column.width
                title: modelData.name
                subtitle: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                trailing: modelData.batteryPercent >= 0 ? Math.round(modelData.batteryPercent) + "%" : ""
                selected: modelData.connected
                dotColor: Tokens.ok
                onClicked: {
                    if (modelData.connected) dd.bluetoothState.disconnectDevice(modelData.address)
                    else if (modelData.paired) dd.bluetoothState.connectDevice(modelData.address)
                    else dd.bluetoothState.pairDevice(modelData.address)
                }
            }
        }

        Label {
            visible: dd.on && dd.list.length === 0
            text: "No devices found yet"
            color: Tokens.inkSoft
        }

        Item { width: 1; height: 6 }
        ActionButton {
            text: "More"
            onClicked: dd.moreRequested(Enums.TileId.Bluetooth)
        }
    }
}
