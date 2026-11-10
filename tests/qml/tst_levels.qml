// Levels, glyphs, key steps and OSD payloads (services/js/levels.js, bar.md §6, notch.md §8).
import QtQuick
import QtTest
import "../../shell/services/js/levels.js" as L

TestCase {
    name: "levels"

    function test_battery_glyphs_and_inks() {
        compare(L.batteryGlyph(100, false, 15, 7).glyph, "battery_full")
        compare(L.batteryGlyph(0, false, 15, 7).glyph, "battery_0_bar")
        compare(L.batteryGlyph(50, false, 15, 7).ink, "main")
        compare(L.batteryGlyph(15, false, 15, 7).ink, "warn")
        compare(L.batteryGlyph(7, false, 15, 7).ink, "crit")
        // charging: never warn or crit, the bolt overlay instead
        const c = L.batteryGlyph(5, true, 15, 7)
        compare(c.ink, "main")
        compare(c.overlay, "bolt")
        // monotonic: more charge never shows an emptier glyph
        let last = -1
        for (let p = 0; p <= 100; p++) {
            const i = L.BATTERY.indexOf(L.batteryGlyph(p, false, 15, 7).glyph)
            verify(i >= last, "battery glyph steps back at " + p)
            last = i
        }
    }
    function test_volume_glyphs() {
        compare(L.volumeGlyph(0.4, true).glyph, "volume_off")
        compare(L.volumeGlyph(0.4, true).ink, "crit")
        compare(L.volumeGlyph(0, false).glyph, "volume_mute")
        compare(L.volumeGlyph(0.3, false).glyph, "volume_down")
        compare(L.volumeGlyph(1.2, false).glyph, "volume_up")
    }
    function test_network_glyphs() {
        compare(L.networkGlyph("wifi", false, 80).glyph, "wifi_off")
        compare(L.networkGlyph("wifi", false, 80).ink, "faint")
        compare(L.networkGlyph("ethernet", true, 0).glyph, "lan")
        compare(L.networkGlyph("wifi", true, 10).glyph, "network_wifi_1_bar")
        compare(L.networkGlyph("wifi", true, 100).glyph, "network_wifi")
    }
    function test_steps_snap_and_clamp() {
        compare(L.step(47, 1, 5, 0, 100), 50)        // snaps to the next multiple
        compare(L.step(45, 1, 5, 0, 100), 50)
        compare(L.step(47, -1, 5, 0, 100), 45)
        compare(L.step(45, -1, 5, 0, 100), 40)
        compare(L.step(98, 1, 5, 0, 100), 100)       // clamped
        compare(L.step(2, -1, 5, 1, 100), 1)         // brightness never below its minimum
        compare(L.step(50, 1, 1, 0, 100), 51)        // fine step
        compare(L.step(100, 1, 5, 0, 150), 105)      // boost range
        compare(L.step(0.57 * 100, 1, 5, 0, 100), 60) // float input from a 0..1 level
    }
    function test_osd_payloads() {
        const v = L.volumeOsd(0.45, false, false, "")
        compare(v.kind, "volume")
        compare(v.level, 45)
        compare(v.max, 100)
        compare(v.value, "45")
        compare(L.volumeOsd(0.45, false, true, "").max, 150)
        const m = L.volumeOsd(0.45, true, false, "Headphones")
        compare(m.value, "Muted")
        compare(m.device, "Headphones")
        compare(L.micOsd(true, "").glyph, "mic_off")
        compare(L.micOsd(true, "").level, -1)
        compare(L.brightnessOsd(0.4).level, 40)
        const k = L.kbdOsd(1, 2)
        compare(k.dots, 1)
        compare(k.steps, 3)
        compare(k.level, -1)
        compare(L.capsOsd(true).value, "Caps Lock on")
        compare(L.layoutOsd("de").value, "de")
    }
    function test_deck_replaces() {
        verify(L.deckReplaces("volume"))
        verify(L.deckReplaces("mic"))
        verify(L.deckReplaces("brightness"))
        verify(!L.deckReplaces("kbd"))
        verify(!L.deckReplaces("caps"))
        verify(!L.deckReplaces("layout"))
    }

    // An invariant of levels refuses the call (any other exception is not a refusal).
    function refuses(f) {
        try { f() } catch (e) { return String(e.message).indexOf("levels invariant:") === 0 }
        return false
    }
    function accepts(f) {
        try { f() } catch (e) { return false }
        return true
    }

    function test_invariants_reject_broken_state() {
        verify(refuses(() => L.batteryGlyph(50, false, 7, 15)))          // warn below crit
        verify(refuses(() => L.batteryGlyph(50, false, 15, 0)))
        verify(refuses(() => L.step(50, 0, 5, 0, 100)))
        verify(refuses(() => L.step(50, 1, 0, 0, 100)))
        verify(refuses(() => L.step(50, 1, 5, 100, 100)))
        verify(refuses(() => L.kbdOsd(3, 2)))
        verify(refuses(() => L.kbdOsd(0, 0)))                           // no light, no OSD
        verify(refuses(() => L.volumeOsd(NaN, false, false, "")))
        verify(refuses(() => L.brightnessOsd(undefined)))
        verify(refuses(() => L.deckReplaces("weather")))
        // an OSD payload: a level within its maximum, dots within the steps
        const p = { kind: "volume", glyph: "volume_up", ink: "main", level: 45, max: 100, dots: -1, steps: 0, value: "45", device: "" }
        verify(accepts(() => L.checkOsd(p)))
        verify(refuses(() => L.checkOsd(Object.assign({}, p, { level: 120 }))))
        verify(refuses(() => L.checkOsd(Object.assign({}, p, { kind: "weather" }))))
        verify(refuses(() => L.checkOsd(Object.assign({}, p, { glyph: "" }))))
        verify(refuses(() => L.checkOsd(Object.assign({}, p, { kind: "kbd", level: -1, dots: 3, steps: 3 }))))
    }
}
