pragma Singleton
// Network: devices, Wi-Fi list, connect, VPN.
// Owner: S3 (status), S5 (Wi-Fi pages, VPN). Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool online: false
    property bool wifiEnabled: false
    // "wifi" | "ethernet" | "none"
    property string kind: "none"
    property string ssid: ""
    // 0..100
    property int strength: 0
    property bool vpnActive: false
    property string vpnName: ""
}
