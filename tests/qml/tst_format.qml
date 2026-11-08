// Formatting rules (03 §4).
import QtQuick
import QtTest
import "../../shell/core/js/format.js" as Lib

TestCase {
    name: "format"

    function test_time() {
        compare(Lib.time(new Date(2026, 10, 7, 14, 32)), "14:32")
        compare(Lib.time(new Date(2026, 10, 7, 0, 5)), "00:05")
        compare(Lib.time(new Date(2026, 10, 7, 9, 0)), "09:00")
    }

    function test_dates() {
        var d = new Date(2026, 10, 7)
        compare(Lib.dateShort(d), "Sat 7 Nov")
        compare(Lib.dateLong(d), "Saturday, 7 November")
        compare(Lib.dateShort(new Date(2026, 0, 1)), "Thu 1 Jan")
    }

    function test_iso_week() {
        compare(Lib.isoWeek(new Date(2026, 10, 7)), 45)
        compare(Lib.isoWeek(new Date(2026, 0, 1)), 1)
        compare(Lib.isoWeek(new Date(2021, 0, 3)), 53)
        compare(Lib.isoWeek(new Date(2024, 11, 30)), 1)
        compare(Lib.isoWeek(new Date(2026, 5, 15)), 25)
    }

    function test_durations() {
        compare(Lib.duration(42), "42 s")
        compare(Lib.duration(0), "0 s")
        compare(Lib.duration(300), "5 min")
        compare(Lib.duration(3 * 3600 + 10 * 60), "3 h 10 min")
        compare(Lib.duration(7200), "2 h")
        compare(Lib.duration(-5), "0 s")
    }

    function test_clock_duration() {
        compare(Lib.clockDuration(24 * 60 + 10), "24:10")
        compare(Lib.clockDuration(3723), "1:02:03")
        compare(Lib.clockDuration(5), "0:05")
        compare(Lib.clockDuration(0), "0:00")
    }

    function test_bytes() {
        compare(Lib.bytes(0), "0 B")
        compare(Lib.bytes(999), "999 B")
        compare(Lib.bytes(4.2e9), "4.2 GB")
        compare(Lib.bytes(1500), "1.5 kB")
        compare(Lib.bytes(250e6), "250 MB")
        compare(Lib.bytes(1.2e12), "1.2 TB")
    }

    function test_percent() {
        compare(Lib.percent(0.64), "64 %")
        compare(Lib.percent(0), "0 %")
        compare(Lib.percent(1), "100 %")
    }

    function test_ago() {
        var now = new Date(2026, 10, 7, 12, 0).getTime()
        compare(Lib.ago(now - 30000, now), "now")
        compare(Lib.ago(now - 2 * 60000, now), "2 min ago")
        compare(Lib.ago(now - 3 * 3600000, now), "3 h ago")
        compare(Lib.ago(new Date(2026, 10, 5, 12, 0).getTime(), now), "Thu")
        compare(Lib.ago(new Date(2026, 9, 20, 12, 0).getTime(), now), "20 Oct")
    }

    function test_tilde() {
        compare(Lib.tildePath("/home/lenno/x/y.txt", "/home/lenno"), "~/x/y.txt")
        compare(Lib.tildePath("/home/lenno", "/home/lenno"), "~")
        compare(Lib.tildePath("/home/lennox/a", "/home/lenno"), "/home/lennox/a")
        compare(Lib.tildePath("/etc/fstab", "/home/lenno"), "/etc/fstab")
        compare(Lib.tildePath("/etc/fstab", ""), "/etc/fstab")
    }

    function test_middle_elide() {
        compare(Lib.middleElide("~/a/b.qml", 20), "~/a/b.qml")
        var s = Lib.middleElide("~/Code/Projekte/aptus/shell/main.qml", 22)
        verify(s.length <= 22)
        verify(s.indexOf("…") > 0)
        verify(s.indexOf("~/Code") === 0)
        verify(s.slice(-8) === "main.qml")
        var t = Lib.middleElide("averyveryverylongfilename.txt", 12)
        compare(t.length, 12)
        verify(t.indexOf("…") > 0)
    }
}
