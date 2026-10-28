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

    // Everything NetworkManager has saved for Wi-Fi, in range or not (nmcli; the hotspot profile is never part of it).
    property var savedProfiles: []    // list of { name, uuid, autoconnect }
    // Quickshell only lists networks that have a saved profile, so everything in range comes from nmcli.
    property var scanned: []          // list of { ssid, signal, secured }
    // The active Wi-Fi link, empty when not connected.
    property var linkDetails: ({})    // { device, ip, gateway, dns, band, channel, rate, security }
    property string ethernetIp

    // Saved profiles joined with what is in range right now: connected first, then in range by signal, then the rest by name.
    property var savedNetworks: savedProfiles.map(p => {
        const n = wifiList.find(x => x.name === p.name)
        return { name: p.name, uuid: p.uuid, autoconnect: p.autoconnect, inRange: !!n, connected: !!n && n.connected, signal: n ? n.signalStrength : 0, secured: n ? n.security !== WifiSecurityType.Open : true }
    }).sort((a, b) => (b.connected - a.connected) || (b.inRange - a.inRange) || (b.signal - a.signal) || a.name.localeCompare(b.name))   // list of { name, uuid, autoconnect, inRange, connected, signal, secured }
    // In range and not saved yet, strongest first (scanned is already sorted).
    property var newNetworks: scanned.filter(n => !savedProfiles.some(p => p.name === n.ssid))   // list of { ssid, signal, secured }

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
        if (!n) {
            // not saved yet, so Quickshell does not know it
            const cmd = ["nmcli", "device", "wifi", "connect", networkName]
            if (password) cmd.push("password", password)
            Quickshell.execDetached(cmd)
            refreshLater.restart()
            return
        }
        if (password) n.connectWithPsk(password)
        else n.connect()
    }

    // Saved networks go through nmcli, so they also work for networks that are out of range.
    function refreshSaved(): void {
        refreshProfiles()
    }

    function refreshLink(): void {
        if (!linkReader.running) linkReader.running = true
    }

    function connectSaved(profileName: string): void {
        if (!profileName) throw new Error("invariant: NetworkState.connectSaved: empty profile name")
        if (!wifiEnabled) throw new Error("invariant: NetworkState.connectSaved: Wi-Fi is off")
        if (!savedProfiles.some(p => p.name === profileName)) return
        Quickshell.execDetached(["nmcli", "connection", "up", "id", profileName])
        refreshLater.restart()
    }

    function setAutoconnect(profileName: string, on: bool): void {
        if (!profileName) throw new Error("invariant: NetworkState.setAutoconnect: empty profile name")
        if (profileName === "Hotspot") throw new Error("invariant: NetworkState.setAutoconnect: the hotspot profile is not a saved network")
        if (!savedProfiles.some(p => p.name === profileName)) return
        Quickshell.execDetached(["nmcli", "connection", "modify", "id", profileName, "connection.autoconnect", on ? "yes" : "no"])
        refreshLater.restart()
    }

    function forgetSaved(profileName: string): void {
        if (!profileName) throw new Error("invariant: NetworkState.forgetSaved: empty profile name")
        if (profileName === "Hotspot") throw new Error("invariant: NetworkState.forgetSaved: the hotspot profile is not a saved network")
        if (!savedProfiles.some(p => p.name === profileName)) return   // a stale list after a change from outside is no error
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", profileName])
        refreshLater.restart()
    }

    function connectHidden(networkName: string, password: string): void {
        if (!networkName) throw new Error("invariant: NetworkState.connectHidden: empty network name")
        if (!wifiEnabled) throw new Error("invariant: NetworkState.connectHidden: Wi-Fi is off")
        if (!wifiDevice) return
        const cmd = ["nmcli", "device", "wifi", "connect", networkName, "hidden", "yes"]
        if (password) cmd.push("password", password)
        Quickshell.execDetached(cmd)
        refreshLater.restart()
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
        onTriggered: { root.refreshProfiles(); root.refreshLink() }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: { root.refreshProfiles(); root.refreshLink() }
    }

    Process {
        id: linkReader
        command: ["sh", "-c", "nmcli -t -f GENERAL.TYPE,GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show; echo @@; nmcli -t -f IN-USE,CHAN,FREQ,RATE,SECURITY,SSID,SIGNAL device wifi list --rescan no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const halves = text.split("@@\n")
                let wifi = null
                let wired = ""
                for (const block of halves[0].split("\n\n")) {
                    const v = {}
                    const dns = []
                    for (const line of block.split("\n")) {
                        const i = line.indexOf(":")
                        if (i < 0) continue
                        const key = line.slice(0, i).replace(/\[\d+\]$/, "")
                        const val = line.slice(i + 1)
                        if (key === "IP4.DNS") dns.push(val)
                        else v[key] = val
                    }
                    if (!v["GENERAL.CONNECTION"]) continue
                    if (v["GENERAL.TYPE"] === "wifi") wifi = { ip: (v["IP4.ADDRESS"] || "").split("/")[0], gateway: v["IP4.GATEWAY"] || "", dns: dns.join(", ") }
                    else if (v["GENERAL.TYPE"] === "ethernet") wired = (v["IP4.ADDRESS"] || "").split("/")[0]
                }
                const seen = {}
                for (const line of (halves[1] || "").split("\n")) {
                    if (!line) continue
                    const f = line.replace(/\\:/g, "\u0001").split(":").map(x => x.replace(/\u0001/g, ":"))
                    const ssid = f[5]
                    const strength = Number(f[6]) / 100
                    if (ssid && !(seen[ssid] && seen[ssid].signal >= strength)) seen[ssid] = { ssid: ssid, signal: strength, secured: f[4] !== "" }
                }
                root.scanned = Object.values(seen).sort((a, b) => b.signal - a.signal)
                if (wifi) {
                    const row = (halves[1] || "").split("\n").find(l => l.startsWith("*:"))
                    if (row) {
                        const f = row.split(":")
                        wifi.channel = f[1]
                        wifi.band = f[2].startsWith("5") ? "5 GHz" : f[2].startsWith("6") ? "6 GHz" : "2.4 GHz"
                        wifi.rate = f[3]
                        wifi.security = f[4] || "Open"
                    }
                }
                root.linkDetails = wifi || ({})
                root.ethernetIp = wired
            }
        }
    }

    Process {
        id: profileReader
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE,DEVICE,UUID,AUTOCONNECT connection show; echo @@; nmcli -s -g 802-11-wireless.ssid,802-11-wireless-security.psk connection show Hotspot 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const halves = text.split("@@\n")
                const profiles = []
                const saved = []
                let hotspotUp = false
                for (const line of halves[0].split("\n")) {
                    if (!line) continue
                    // Fields are separated by ':' and a ':' inside a field is escaped as '\:'.
                    const f = line.replace(/\\:/g, "\u0001").split(":").map(x => x.replace(/\u0001/g, ":"))
                    if (f[0] === "Hotspot") hotspotUp = f[2] !== ""
                    if (f[1] === "802-11-wireless" && f[0] !== "Hotspot") saved.push({ name: f[0], uuid: f[3], autoconnect: f[4] === "yes" })
                    if (f[1] === "vpn" || f[1] === "wireguard") profiles.push({ id: f[0], name: f[0], active: f[2] !== "" })
                }
                root.savedProfiles = saved
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
