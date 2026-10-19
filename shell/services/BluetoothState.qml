import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth state (BlueZ).
Scope {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    // qmllint disable unresolved-type
    readonly property var liveDevices: Array.from(Bluetooth.devices.values)
    // qmllint enable unresolved-type

    property bool powered: adapter ? adapter.enabled : false
    property bool discovering: adapter ? adapter.discovering : false
    // Connected first, then paired, then the rest by name. Unnamed devices are noise and stay out.
    property var devices: liveDevices
        .filter(d => d.name && (d.paired || d.connected || discovering))
        .map(d => ({ address: d.address, name: d.name, connected: d.connected, paired: d.paired, batteryPercent: d.batteryAvailable ? (d.battery <= 1 ? d.battery * 100 : d.battery) : -1 }))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))   // list of { address, name, connected, paired, batteryPercent }
    property int connectedCount: devices.filter(d => d.connected).length

    function byAddress(address: string): var {
        return liveDevices.find(d => d.address === address)
    }

    function setPowered(on: bool): void {
        if (adapter) adapter.enabled = on
    }

    function startDiscovery(): void {
        if (!powered) throw new Error("invariant: BluetoothState.startDiscovery: Bluetooth is off")
        if (adapter) adapter.discovering = true
    }

    function stopDiscovery(): void {
        if (adapter) adapter.discovering = false
    }

    function connectDevice(address: string): void {
        if (!/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(address)) throw new Error("invariant: BluetoothState.connectDevice: not a Bluetooth address")
        if (!powered) throw new Error("invariant: BluetoothState.connectDevice: Bluetooth is off")
        const d = byAddress(address)
        if (d) d.connect()
    }

    function disconnectDevice(address: string): void {
        if (!/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(address)) throw new Error("invariant: BluetoothState.disconnectDevice: not a Bluetooth address")
        const d = byAddress(address)
        if (d) d.disconnect()
    }

    function pairDevice(address: string): void {
        if (!/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(address)) throw new Error("invariant: BluetoothState.pairDevice: not a Bluetooth address")
        if (!powered) throw new Error("invariant: BluetoothState.pairDevice: Bluetooth is off")
        const d = byAddress(address)
        if (d) d.pair()
    }

    function forgetDevice(address: string): void {
        if (!/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(address)) throw new Error("invariant: BluetoothState.forgetDevice: not a Bluetooth address")
        const d = byAddress(address)
        if (d) d.forget()
    }
}
