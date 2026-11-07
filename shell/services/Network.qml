pragma Singleton
// Network: devices, Wi-Fi list, connect, VPN.
// Owner: S3 (status), S5 (Wi-Fi pages, VPN). Stub until its stage fills it.
import QtQuick
import Quickshell

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
    function setWifiEnabled(on: bool): void { throw new Error("Network.setWifiEnabled: not implemented"); }
    function setAirplane(on: bool): void { throw new Error("Network.setAirplane: not implemented"); }
    function connectVpn(name: string): void { throw new Error("Network.connectVpn: not implemented"); }
    function disconnectVpn(): void { throw new Error("Network.disconnectVpn: not implemented"); }
    // Connect to a network; password "" for known or open ones.
    function connect(ssid: string, password: string): void { throw new Error("Network.connect: not implemented"); }
}
