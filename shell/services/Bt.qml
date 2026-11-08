pragma Singleton
// Bt: adapter, devices, pairing.
// Owner: S3 (status), S5 (pages). Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // [{ address, name, icon, paired: bool, connected: bool, battery: int (-1 unknown) }]
    property var devices: []

    // an adapter exists
    property bool available: false
    property bool enabled: false
    // connected devices: [{ name, battery }]
    property var connected: []
    function setEnabled(on: bool): void { Log.info("service.bt", "setEnabled: not available yet"); }
    function connectDevice(address: string): void { Log.info("service.bt", "connectDevice: not available yet"); }
    function disconnectDevice(address: string): void { Log.info("service.bt", "disconnectDevice: not available yet"); }
}
