pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// The Bluetooth section of the hover card: the known and nearby devices, a tap connects or disconnects.
// Discovery runs only while the section is shown.
FocusScope {
    id: bluetooth

    property var bluetoothState
    property bool shown                 // true while the section is open: discovery only then
    property int maxRows: 5
    property color ink
    property color inkSoft
    property color line
    property color fill

    readonly property bool powered: bluetoothState ? bluetoothState.powered : false
    // Devices that only have their address as a name are noise (nearby, not paired).
    readonly property var rows: bluetoothState && powered ? bluetoothState.devices.filter(d => d.paired || d.connected || !/^([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}$/.test(d.name)).slice(0, maxRows) : []

    implicitHeight: column.implicitHeight

    // Discovery runs only while the section is shown.
    onShownChanged: {
        if (!bluetoothState) return
        if (shown && powered) bluetoothState.startDiscovery()
        else bluetoothState.stopDiscovery()
    }
    Component.onDestruction: if (bluetoothState) bluetoothState.stopDiscovery()
    Keys.onEscapePressed: closeRequested()

    signal closeRequested()

    // A tap on a device: connect when it is not connected, else disconnect.
    function toggleDevice(address: string): void {
        if (!address) throw new Error("invariant: IslandBluetooth.toggleDevice: empty device address")
        if (!bluetoothState || !bluetoothState.powered) throw new Error("invariant: IslandBluetooth.toggleDevice: Bluetooth is off")
        const d = bluetoothState.devices.find(x => x.address === address)
        if (!d) return
        if (d.connected) bluetoothState.disconnectDevice(address)
        else if (d.paired) bluetoothState.connectDevice(address)
        else bluetoothState.pairDevice(address)
    }

    Column {
        id: column
        width: parent.width

        Label {
            visible: !bluetooth.powered || bluetooth.rows.length === 0
            height: visible ? 30 : 0
            verticalAlignment: Text.AlignVCenter
            text: !bluetooth.powered ? "Bluetooth is off" : "No devices found"
            role: Enums.TextRole.Bar
            color: bluetooth.inkSoft
        }

        Repeater {
            model: bluetooth.rows
            delegate: Item {
                id: entry
                required property var modelData
                width: column.width
                height: 34
                Rectangle {
                    visible: entry.modelData.connected
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 6; height: 6; radius: 3
                    color: Tokens.ok
                }
                Label {
                    anchors { left: parent.left; leftMargin: 14; right: sub.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: entry.modelData.name
                    role: Enums.TextRole.Bar
                    elide: Text.ElideRight
                    color: bluetooth.ink
                    font.weight: entry.modelData.connected ? Font.DemiBold : Font.Normal
                }
                Label {
                    id: sub
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: (entry.modelData.connected ? "Connected" : entry.modelData.paired ? "Paired" : "Pair") + (entry.modelData.batteryPercent >= 0 ? "  " + Math.round(entry.modelData.batteryPercent) + "%" : "")
                    role: Enums.TextRole.Bar
                    color: bluetooth.inkSoft
                }
                MouseArea { anchors.fill: parent; onClicked: bluetooth.toggleDevice(entry.modelData.address) }
            }
        }
    }
}
