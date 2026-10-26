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

    signal closeRequested()

    // A tap on a device: connect when it is not connected, else disconnect.
    function toggleDevice(address: string): void {
        if (!address) throw new Error("invariant: IslandBluetooth.toggleDevice: empty device address")
        if (!bluetoothState || !bluetoothState.powered) throw new Error("invariant: IslandBluetooth.toggleDevice: Bluetooth is off")
        throw new Error("not implemented")
    }
}
