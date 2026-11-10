pragma Singleton
pragma ComponentBehavior: Bound
// Bt: adapter, devices, pairing.
// Owner: S3 (status), S5 (pages).
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.core
import "js/status.js" as S

Singleton {
    id: root

    // [{ address, name, icon, paired: bool, connected: bool, battery: int (-1 unknown) }]
    property var devices: []

    // an adapter exists
    readonly property bool available: !!_adapter
    readonly property bool enabled: available && _adapter.enabled
    // connected devices: [{ name, battery }] (battery 0..100, -1 unknown)
    readonly property var connected: (available ? _adapter.devices.values : [])
        .filter(d => d.connected).map(d => ({ name: d.name, battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1 }))
    // The Bluetooth singleton and its default adapter, untyped (qmllint has no types for them).
    readonly property var _bt: Bluetooth
    readonly property var _adapter: _bt.defaultAdapter
    // Devices already connected at start make no event (they connect while bluez answers).
    property bool _started: false
    Timer { interval: 3000; running: true; onTriggered: root._started = true }
    Instantiator {
        model: root._bt.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged(): void { if (modelData.connected) root._deviceConnected(modelData); }
        }
    }
    // Right click on the bar's Bluetooth item (bar.md §6): refused under Paths.test (the tests
    // never switch the real adapter).
    function setEnabled(on: bool): void {
        if (Paths.test) { Log.info("service.bt", "setEnabled refused under the test"); return; }
        if (_adapter) _adapter.enabled = on;
    }
    function connectDevice(address: string): void { Log.info("service.bt", "connectDevice: not available yet"); }
    function disconnectDevice(address: string): void { Log.info("service.bt", "disconnectDevice: not available yet"); }

    // A device connected: the event "<name> connected · 70 %" (notch.md §7, status.js).
    function _deviceConnected(device: var): void {
        if (!_started) return;
        SurfaceManager.post("event", S.btConnectedEvent(device.name, device.icon,
                            device.batteryAvailable ? device.battery * 100 : -1));
    }
}
