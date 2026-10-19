import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io

// Network state (NetworkManager).
Scope {
    id: root

    readonly property var wifiDevice: Array.from(Networking.devices.values).find(d => d.type === DeviceType.Wifi)
    readonly property var wiredDevices: Array.from(Networking.devices.values).filter(d => d.type === DeviceType.Wired)

    property bool wifiEnabled: Networking.wifiEnabled
    property bool connected: wifiDevice ? wifiDevice.connected : false
    property string ssid: {
        const n = wifiList.find(x => x.connected)
        return n ? n.name : ""
    }
    property real signalStrength: {        // 0..1
        const n = wifiList.find(x => x.connected)
        return n ? n.signalStrength : 0
    }
    property var networks: wifiList.map(n => ({ ssid: n.name, signal: n.signalStrength, secured: n.security !== WifiSecurityType.Open, known: n.known, connected: n.connected }))
        .sort((a, b) => (b.connected - a.connected) || (b.signal - a.signal))   // list of { ssid, signal, secured, known, connected }
    property bool scanning: wifiDevice ? wifiDevice.scannerEnabled : false
    property bool vpnActive
    property string vpnName
    property var vpnProfiles         // list of { id, name, active }
    property bool hotspotActive
    property string hotspotSsid
    property string hotspotPassword
    property int hotspotClients
    property bool ethernetConnected: wiredDevices.some(d => d.connected)

    // The Wi-Fi networks of the device (live objects).
    readonly property var wifiList: wifiDevice ? Array.from(wifiDevice.networks.values) : []

    function byName(networkName: string): var {
        return wifiList.find(n => n.name === networkName)
    }

    function setWifiEnabled(on: bool): void {
        Networking.wifiEnabled = on
    }

    // Scanning runs only while someone looks at the list.
    function scan(): void {
        if (!wifiEnabled) throw new Error("invariant: NetworkState.scan: Wi-Fi is off")
        if (wifiDevice) wifiDevice.scannerEnabled = true
    }

    function stopScan(): void {
        if (wifiDevice) wifiDevice.scannerEnabled = false
    }

    function connectTo(networkName: string, password: string): void {
        if (!networkName) throw new Error("invariant: NetworkState.connectTo: empty network name")
        if (!wifiEnabled) throw new Error("invariant: NetworkState.connectTo: Wi-Fi is off")
        const n = byName(networkName)
        if (!n) return
        if (password) n.connectWithPsk(password)
        else n.connect()
    }

    function disconnectWifi(): void {
        if (wifiDevice) wifiDevice.disconnect()
    }

    function forget(networkName: string): void {
        if (!networkName) throw new Error("invariant: NetworkState.forget: empty network name")
        const n = byName(networkName)
        if (n) n.forget()
    }

    // VPN profiles and the hotspot go through nmcli (NetworkManager); the lists refresh every 10 s and after each change.
    function refreshProfiles(): void {
        if (!profileReader.running) profileReader.running = true
    }

    function setVpn(profileId: string, on: bool): void {
        if (!profileId) throw new Error("invariant: NetworkState.setVpn: empty VPN profile id")
        Quickshell.execDetached(["nmcli", "connection", on ? "up" : "down", "id", profileId])
        refreshLater.restart()
    }

    function setHotspot(on: bool): void {
        if (on) {
            hotspotProc.command = ["nmcli", "device", "wifi", "hotspot"]
            hotspotProc.running = true
        } else {
            Quickshell.execDetached(["nmcli", "connection", "down", "Hotspot"])
        }
        refreshLater.restart()
    }

    Process {
        id: hotspotProc
    }

    Timer {
        id: refreshLater
        interval: 2500
        onTriggered: root.refreshProfiles()
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshProfiles()
    }

    Process {
        id: profileReader
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE,DEVICE connection show; echo @@; nmcli -s -g 802-11-wireless.ssid,802-11-wireless-security.psk connection show Hotspot 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const halves = text.split("@@\n")
                const profiles = []
                let hotspotUp = false
                for (const line of halves[0].split("\n")) {
                    if (!line) continue
                    // Fields are separated by ':' and a ':' inside a field is escaped as '\:'.
                    const f = line.replace(/\\:/g, "\u0001").split(":").map(x => x.replace(/\u0001/g, ":"))
                    if (f[0] === "Hotspot") hotspotUp = f[2] !== ""
                    if (f[1] === "vpn" || f[1] === "wireguard") profiles.push({ id: f[0], name: f[0], active: f[2] !== "" })
                }
                root.vpnProfiles = profiles
                const act = profiles.find(x => x.active)
                root.vpnActive = !!act
                root.vpnName = act ? act.name : ""
                root.hotspotActive = hotspotUp
                const secrets = (halves[1] || "").split("\n")
                root.hotspotSsid = secrets[0] || ""
                root.hotspotPassword = secrets[1] || ""
            }
        }
    }
}
