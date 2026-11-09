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
    // TODO(phase): Bluetooth.defaultAdapter !== null; enabled = its `enabled`; connected from its
    //   devices (connected, batteryAvailable → battery × 100, else -1); a device that turns
    //   connected → _deviceConnected (not those already connected at start).
    property bool available: false
    property bool enabled: false
    // connected devices: [{ name, battery }]
    property var connected: []
    // TODO(phase): right click on the bar's Bluetooth item (bar.md §6): the adapter's `enabled`;
    //   refused (logged) under Paths.test, the tests never switch the real adapter.
    function setEnabled(on: bool): void { Log.info("service.bt", "setEnabled: not available yet"); }
    function connectDevice(address: string): void { Log.info("service.bt", "connectDevice: not available yet"); }
    function disconnectDevice(address: string): void { Log.info("service.bt", "disconnectDevice: not available yet"); }

    // A device connected: the event "<name> connected · 70 %" (notch.md §7, status.js).
    function _deviceConnected(device: var): void { throw new Error("not implemented"); }
}
