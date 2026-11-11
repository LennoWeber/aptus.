.pragma library
// Status logic of the services behind the bar's status cluster (surfaces/bar.md §6) and the S3
// events (surfaces/notch.md §7): privacy streams, the VPN read from nmcli, and the event payloads
// of Bluetooth, Wi-Fi and the charger.
//
// A PipeWire node as Privacy reads it (plain fields off a PwNode; PwNode has no state):
//   { isStream: bool, mediaClass: string ("Stream/Input/Audio", "Video/Source", …),
//     app: string (application.name, else node.name), linked: bool (an Active link group
//     reads from it: a camera source in use) }
//
// The privacy summary: { mic: [app], camera: [app] } (distinct names, first seen first).
//
// An event payload (SurfaceManager.post("event", payload)): { text, glyph } (notch.md §7).

// The media classes that mean "in use" (bar.md §6: a stream recording from a mic, a camera node).
var MIC_CLASS = "Stream/Input/Audio"
var CAMERA_CLASSES = ["Video/Source", "Stream/Input/Video"]
// The glyphs of the S3 events.
var EVENT_GLYPHS = { headphones: "headphones", bluetooth: "bluetooth_connected", charging: "bolt",
    wifiOff: "wifi_off" }

// "mic" | "camera" | "" for one node.
function privacyKind(node) {
    if (!node) return ""
    if (node.mediaClass === MIC_CLASS && node.isStream) return "mic"
    if (CAMERA_CLASSES.indexOf(node.mediaClass) >= 0) return node.isStream || node.linked ? "camera" : ""
    return ""
}
// The privacy summary of every node.
function privacy(nodes) {
    invariant(Array.isArray(nodes), "nodes is not a list")
    var mic = [], camera = []
    for (var i = 0; i < nodes.length; i++) {
        var k = privacyKind(nodes[i]), app = String(nodes[i].app || "")
        if (k === "mic" && mic.indexOf(app) < 0) mic.push(app)
        else if (k === "camera" && camera.indexOf(app) < 0) camera.push(app)
    }
    return { mic: mic, camera: camera }
}
// The active VPN's name from `nmcli -t -f NAME,TYPE connection show --active` ("" none;
// types vpn and wireguard).
function vpnFrom(text) {
    invariant(typeof text === "string", "nmcli output is not a string")
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        // nmcli -t escapes ':' in values as '\:'
        var m = /^((?:[^:\\]|\\.)*):(.*)$/.exec(line)
        if (!m) continue
        var type = m[2].trim()
        if (type === "vpn" || type === "wireguard") return m[1].replace(/\\(.)/g, "$1")
    }
    return ""
}
// "Headphones connected · 70 %": a Bluetooth device's name and battery (-1 unknown); its bluez
// icon name picks the glyph (audio-headset / audio-headphones → headphones).
function btConnectedEvent(name, icon, battery) {
    var headphones = /audio-head(set|phones)/.test(String(icon || ""))
    var text = String(name || "Device") + " connected" + (battery >= 0 ? " · " + Math.round(battery) + " %" : "")
    return { text: text, glyph: headphones ? EVENT_GLYPHS.headphones : EVENT_GLYPHS.bluetooth }
}
// "Charging" (plugged in while discharging) and "Wi-Fi off".
function chargingEvent() {
    return { text: "Charging", glyph: EVENT_GLYPHS.charging }
}
function wifiOffEvent() {
    return { text: "Wi-Fi off", glyph: EVENT_GLYPHS.wifiOff }
}

// Invariants (phase 6): they throw "status invariant: …".
function invariant(cond, message) { if (!cond) throw new Error("status invariant: " + message) }
