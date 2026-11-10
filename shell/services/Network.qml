pragma Singleton
// Network: devices, Wi-Fi list, connect, VPN.
// Owner: S3 (status), S5 (Wi-Fi pages, VPN). Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // the Wi-Fi list (S5): [{ ssid, strength, secure: bool, known: bool, active: bool }]
    property var networks: []
    // [{ name, active: bool }]
    property var vpns: []
    property bool airplane: false

    // TODO(phase): online … strength from Networking (connectivity Full/Limited/Portal = online;
    //   the first connected device's type; the active WifiNetwork's name and signalStrength × 100);
    //   wifiEnabled from Networking.wifiEnabled, off → _wifiChanged.
    property bool online: false
    property bool wifiEnabled: false
    // "wifi" | "ethernet" | "none"
    property string kind: "none"
    property string ssid: ""
    // 0..100
    property int strength: 0
    // TODO(phase): a read-only `nmcli -t -f NAME,TYPE connection show --active` Process → _readVpn,
    //   at start and whenever a long-running `nmcli monitor` prints a line (no nmcli: no VPN).
    property bool vpnActive: false
    property string vpnName: ""
    // The service works (S3: status).
    // TODO(phase): true once Networking has a backend.
    readonly property bool available: false
    // TODO(phase): right click on the bar's network item (bar.md §6): Networking.wifiEnabled;
    //   refused (logged) under Paths.test.
    function setWifiEnabled(on: bool): void { Log.info("service.network", "setWifiEnabled: not available yet"); }
    function setAirplane(on: bool): void { Log.info("service.network", "setAirplane: not available yet"); }
    function connectVpn(name: string): void { Log.info("service.network", "connectVpn: not available yet"); }
    function disconnectVpn(): void { Log.info("service.network", "disconnectVpn: not available yet"); }
    // Connect to a network; password "" for known or open ones.
    function connect(ssid: string, password: string): void { Log.info("service.network", "connect: not available yet"); }

    // The output of `nmcli -t -f NAME,TYPE connection show --active` (status.js vpnFrom; Networking
    // has no VPN device type): vpnActive, vpnName.
    function _readVpn(text: string): void { throw new Error("not implemented"); }
    // Wi-Fi was switched off: the event "Wi-Fi off" (notch.md §7).
    function _wifiChanged(): void { throw new Error("not implemented"); }

    // Found by the probe (phase 5):
    // NetworkManager's devices, the Wi-Fi device, a connected wired device and the connected
    // Wi-Fi network (null when none).
    // TODO(phase): Networking.devices.values and finds on it (`_wifi` would clash with the
    //   generated `_wifiChanged`, hence `_wifiDevice`).
    readonly property var _devices: []
    readonly property var _wifiDevice: null
    readonly property var _wired: null
    readonly property var _wifiNet: null
    // The connection at start makes no event: the first state after start is taken as it is.
    property bool _started: false
}
