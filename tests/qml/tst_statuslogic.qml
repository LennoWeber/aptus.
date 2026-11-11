// Privacy, VPN and the S3 events (services/js/status.js, bar.md §6, notch.md §7).
import QtQuick
import QtTest
import "../../shell/services/js/status.js" as S

TestCase {
    name: "statuslogic"

    function test_privacy_kinds() {
        compare(S.privacyKind({ isStream: true, mediaClass: "Stream/Input/Audio", app: "zoom", linked: false }), "mic")
        compare(S.privacyKind({ isStream: true, mediaClass: "Stream/Output/Audio", app: "mpv", linked: false }), "")
        // a camera source counts only while something reads from it
        compare(S.privacyKind({ isStream: false, mediaClass: "Video/Source", app: "cam", linked: false }), "")
        compare(S.privacyKind({ isStream: false, mediaClass: "Video/Source", app: "cam", linked: true }), "camera")
        compare(S.privacyKind({ isStream: true, mediaClass: "Stream/Input/Video", app: "obs", linked: false }), "camera")
        compare(S.privacyKind(null), "")
    }
    function test_privacy_summary_is_distinct() {
        const r = S.privacy([
            { isStream: true, mediaClass: "Stream/Input/Audio", app: "zoom", linked: false },
            { isStream: true, mediaClass: "Stream/Input/Audio", app: "zoom", linked: false },
            { isStream: true, mediaClass: "Stream/Input/Audio", app: "Firefox", linked: false },
            { isStream: false, mediaClass: "Video/Source", app: "zoom", linked: true }])
        compare(r.mic, ["zoom", "Firefox"])
        compare(r.camera, ["zoom"])
    }
    function test_vpn_from_nmcli() {
        compare(S.vpnFrom("Home:802-11-wireless\nwork:vpn\n"), "work")
        compare(S.vpnFrom("wg0:wireguard\n"), "wg0")
        compare(S.vpnFrom("a\\:b:vpn\n"), "a:b")               // nmcli -t escapes ':'
        compare(S.vpnFrom("Home:802-11-wireless\n"), "")
        compare(S.vpnFrom(""), "")
    }
    function test_event_payloads() {
        const h = S.btConnectedEvent("WH-1000XM4", "audio-headset", 70)
        compare(h.text, "WH-1000XM4 connected · 70 %")
        compare(h.glyph, "headphones")
        compare(S.btConnectedEvent("Mouse", "input-mouse", -1).text, "Mouse connected")
        compare(S.btConnectedEvent("Mouse", "input-mouse", -1).glyph, "bluetooth_connected")
        compare(S.chargingEvent().text, "Charging")
        compare(S.wifiOffEvent().glyph, "wifi_off")
    }

    // An invariant of status refuses the call (any other exception is not a refusal).
    function refuses(f) {
        try { f() } catch (e) { return String(e.message).indexOf("status invariant:") === 0 }
        return false
    }
    function accepts(f) {
        try { f() } catch (e) { return false }
        return true
    }

    function test_invariants_reject_broken_state() {
        verify(refuses(() => S.privacy(null)))
        verify(refuses(() => S.vpnFrom(null)))
    }
}
