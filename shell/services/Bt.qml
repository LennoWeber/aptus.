pragma Singleton
// Bt: adapter, devices, pairing.
// Owner: S3 (status), S5 (pages). Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // [{ address, name, icon, paired: bool, connected: bool, battery: int (-1 unknown) }]
    property var devices: []

    // an adapter exists
    property bool available: false
    property bool enabled: false
    // connected devices: [{ name, battery }]
    property var connected: []
    function setEnabled(on: bool): void { throw new Error("Bt.setEnabled: not implemented"); }
    function connectDevice(address: string): void { throw new Error("Bt.connectDevice: not implemented"); }
    function disconnectDevice(address: string): void { throw new Error("Bt.disconnectDevice: not implemented"); }
}
