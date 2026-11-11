pragma Singleton
// Network: devices, Wi-Fi list, connect, VPN.
// Owner: S3 (status), S5 (Wi-Fi pages, VPN).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.core
import "js/status.js" as S

Singleton {
    id: root

    // the Wi-Fi list (S5): [{ ssid, strength, secure: bool, known: bool, active: bool }]
    property var networks: []
    // [{ name, active: bool }]
    property var vpns: []
    property bool airplane: false

    // Found by the probe (phase 5):
    // NetworkManager's devices, the Wi-Fi device, a connected wired device and the connected
    // Wi-Fi network (null when none).
    readonly property var _devices: Networking.devices.values
    readonly property var _wifiDevice: _devices.find(d => d.type === DeviceType.Wifi) || null
    readonly property var _wired: _devices.find(d => d.type === DeviceType.Wired && d.connected) || null
    readonly property var _wifiNet: _wifiDevice ? (_wifiDevice.networks.values.find(n => n.connected) || null) : null
    readonly property bool online: Networking.connectivity === NetworkConnectivity.Full
        || Networking.connectivity === NetworkConnectivity.Limited || Networking.connectivity === NetworkConnectivity.Portal
    readonly property bool wifiEnabled: Networking.wifiEnabled
    // "wifi" | "ethernet" | "none"
    readonly property string kind: _wired ? "ethernet" : (_wifiNet ? "wifi" : "none")
    readonly property string ssid: _wifiNet ? _wifiNet.name : ""
    // 0..100
    readonly property int strength: _wifiNet ? Math.round(_wifiNet.signalStrength * 100) : 0
    // From a read-only `nmcli -t -f NAME,TYPE connection show --active`, at start and after a
    // long-running `nmcli monitor` prints (debounced; no nmcli: no VPN).
    property bool vpnActive: false
    property string vpnName: ""
    // The service works (S3: status) once Networking has a backend.
    readonly property bool available: Networking.backend !== NetworkBackendType.None
    // The connection at start makes no event: the first state after start is taken as it is.
    property bool _started: false
    onWifiEnabledChanged: _wifiChanged()
    // Right click on the bar's network item (bar.md §6); refused under Paths.test.
    function setWifiEnabled(on: bool): void {
        if (Paths.test) { Log.info("service.network", "setWifiEnabled refused under the test"); return; }
        Networking.wifiEnabled = on;
    }
    function setAirplane(on: bool): void { Log.info("service.network", "setAirplane: not available yet"); }
    function connectVpn(name: string): void { Log.info("service.network", "connectVpn: not available yet"); }
    function disconnectVpn(): void { Log.info("service.network", "disconnectVpn: not available yet"); }
    // Connect to a network; password "" for known or open ones.
    function connect(ssid: string, password: string): void { Log.info("service.network", "connect: not available yet"); }

    // The output of `nmcli -t -f NAME,TYPE connection show --active` (status.js vpnFrom; Networking
    // has no VPN device type): vpnActive, vpnName.
    function _readVpn(text: string): void {
        vpnName = S.vpnFrom(text);
        vpnActive = vpnName !== "";
    }
    // Wi-Fi was switched off: the event "Wi-Fi off" (notch.md §7).
    function _wifiChanged(): void {
        if (_started && !wifiEnabled) SurfaceManager.post("event", S.wifiOffEvent());
    }

    Process {
        id: vpnRead
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"]
        stdout: StdioCollector { onStreamFinished: root._readVpn(text) }
    }
    Process {
        id: nmMonitor
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: _ => vpnDebounce.restart() }
    }
    Timer { id: vpnDebounce; interval: 500; onTriggered: vpnRead.running = true }
    Timer { interval: 2000; running: true; onTriggered: root._started = true }
    Component.onCompleted: {
        vpnRead.running = true;
        nmMonitor.running = true;
    }
}
