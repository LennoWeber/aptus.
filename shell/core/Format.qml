pragma Singleton
// Text formatting rules of 03-visual-language §4: 24 h time, "Sat 7 Nov", week starts Monday,
// decimal point, durations, sizes, middle-truncated paths.
import QtQuick
import Quickshell
import "js/format.js" as F

Singleton {
    id: root

    // Wrappers of core/js/format.js (03 §4).
    function time(date: var): string { return F.time(date); }
    function dateShort(date: var): string { return F.dateShort(date); }
    function dateLong(date: var): string { return F.dateLong(date); }
    function isoWeek(date: var): int { return F.isoWeek(date); }
    function duration(seconds: real): string { return F.duration(seconds); }
    function clockDuration(seconds: real): string { return F.clockDuration(seconds); }
    function bytes(n: real): string { return F.bytes(n); }
    function percent(fraction: real): string { return F.percent(fraction); }
    function ago(ms: real): string { return F.ago(ms, Date.now()); }
    function tildePath(path: string): string { return F.tildePath(path, Paths.home); }
    function middleElide(path: string, maxChars: int): string { return F.middleElide(path, maxChars); }
}
