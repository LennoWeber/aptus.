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

    property bool online: false
    property bool wifiEnabled: false
    // "wifi" | "ethernet" | "none"
    property string kind: "none"
    property string ssid: ""
    // 0..100
    property int strength: 0
    property bool vpnActive: false
    property string vpnName: ""
    // The service works (S3: status).
    readonly property bool available: false
    function setWifiEnabled(on: bool): void { Log.info("service.network", "setWifiEnabled: not available yet"); }
    function setAirplane(on: bool): void { Log.info("service.network", "setAirplane: not available yet"); }
    function connectVpn(name: string): void { Log.info("service.network", "connectVpn: not available yet"); }
    function disconnectVpn(): void { Log.info("service.network", "disconnectVpn: not available yet"); }
    // Connect to a network; password "" for known or open ones.
    function connect(ssid: string, password: string): void { Log.info("service.network", "connect: not available yet"); }
}
