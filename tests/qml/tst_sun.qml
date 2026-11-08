// NOAA sunrise and sunset.
import QtQuick
import QtTest
import "../../shell/core/js/sun.js" as Lib

TestCase {
    name: "sun"

    readonly property var berlin: ({ lat: 52.52, lon: 13.405 })

    function mins(d) { return d.getHours() * 60 + d.getMinutes() }

    function test_known_city() {
        // Local-time check only valid when the runner's zone is Berlin; otherwise compare in UTC.
        var day = new Date(2026, 5, 21, 12, 0)
        var t = Lib.times(day, berlin)
        var offset = -day.getTimezoneOffset()      // minutes east of UTC
        var shift = offset - 120                   // vs CEST
        var rise = mins(t.sunrise) - shift, set = mins(t.sunset) - shift
        verify(Math.abs(rise - (4 * 60 + 43)) <= 3, "sunrise " + rise)
        verify(Math.abs(set - (21 * 60 + 33)) <= 3, "sunset " + set)
        verify(t.sunrise < t.sunset)
        // winter day is shorter
        var w = Lib.times(new Date(2026, 11, 21, 12, 0), berlin)
        verify(w.sunset - w.sunrise < t.sunset - t.sunrise)
    }

    function test_fallback_without_location() {
        var day = new Date(2026, 5, 21, 12, 0)
        var ts = [Lib.times(day, null), Lib.times(day, undefined), Lib.times(day, {})]
        for (var i = 0; i < ts.length; i++) {
            compare(ts[i].sunrise.getHours(), 7)
            compare(ts[i].sunrise.getMinutes(), 0)
            compare(ts[i].sunset.getHours(), 19)
            compare(ts[i].sunset.getMinutes(), 0)
        }
    }

    function test_polar() {
        var tromso = { lat: 69.65, lon: 18.96 }
        var day = new Date(2026, 5, 21, 12, 0)
        var t = Lib.times(day, tromso)
        // midnight sun: light all day
        compare(t.sunrise.getHours(), 0)
        compare(t.sunset.getTime() - t.sunrise.getTime(), 24 * 3600 * 1000)
        compare(Lib.modeAt(new Date(2026, 5, 21, 2, 0), tromso), "light")
        compare(Lib.modeAt(new Date(2026, 5, 21, 23, 30), tromso), "light")
        // polar night: dark all day
        var n = new Date(2026, 11, 21, 12, 0)
        compare(Lib.modeAt(n, tromso), "dark")
        var tn = Lib.times(n, tromso)
        compare(tn.sunrise.getTime(), tn.sunset.getTime())
        // nextChange during the polar night lands on a later day with daylight
        var nc = Lib.nextChange(n, tromso)
        verify(nc > n)
    }

    function test_mode_at() {
        compare(Lib.modeAt(new Date(2026, 5, 21, 12, 0), berlin), "light")
        compare(Lib.modeAt(new Date(2026, 5, 21, 2, 0), berlin), "dark")
        compare(Lib.modeAt(new Date(2026, 5, 21, 23, 0), berlin), "dark")
        // fallback boundaries 07:00 (inclusive) and 19:00 (exclusive)
        compare(Lib.modeAt(new Date(2026, 5, 21, 6, 59), null), "dark")
        compare(Lib.modeAt(new Date(2026, 5, 21, 7, 0), null), "light")
        compare(Lib.modeAt(new Date(2026, 5, 21, 18, 59), null), "light")
        compare(Lib.modeAt(new Date(2026, 5, 21, 19, 0), null), "dark")
    }

    function test_next_change() {
        var d = new Date(2026, 10, 7, 5, 0)
        var n = Lib.nextChange(d, null)
        compare(n.getTime(), new Date(2026, 10, 7, 7, 0).getTime())
        n = Lib.nextChange(new Date(2026, 10, 7, 12, 0), null)
        compare(n.getTime(), new Date(2026, 10, 7, 19, 0).getTime())
        n = Lib.nextChange(new Date(2026, 10, 7, 20, 0), null)
        compare(n.getTime(), new Date(2026, 10, 8, 7, 0).getTime())
        // the change really flips the mode
        var c = Lib.nextChange(new Date(2026, 5, 21, 12, 0), berlin)
        compare(Lib.modeAt(new Date(c.getTime() - 60000), berlin), "light")
        compare(Lib.modeAt(new Date(c.getTime() + 60000), berlin), "dark")
    }
}
