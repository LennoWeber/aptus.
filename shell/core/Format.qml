pragma Singleton
// Text formatting rules of 03-visual-language §4: 24 h time, "Sat 7 Nov", week starts Monday,
// decimal point, durations, sizes, middle-truncated paths.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): `import "js/format.js" as F` and forward each wrapper (ago uses Date.now()).

    // Wrappers of core/js/format.js (03 §4).
    function time(date: var): string { throw new Error("Format.time: not implemented"); }
    function dateShort(date: var): string { throw new Error("Format.dateShort: not implemented"); }
    function dateLong(date: var): string { throw new Error("Format.dateLong: not implemented"); }
    function isoWeek(date: var): int { throw new Error("Format.isoWeek: not implemented"); }
    function duration(seconds: real): string { throw new Error("Format.duration: not implemented"); }
    function clockDuration(seconds: real): string { throw new Error("Format.clockDuration: not implemented"); }
    function bytes(n: real): string { throw new Error("Format.bytes: not implemented"); }
    function percent(fraction: real): string { throw new Error("Format.percent: not implemented"); }
    function ago(ms: real): string { throw new Error("Format.ago: not implemented"); }
    function tildePath(path: string): string { throw new Error("Format.tildePath: not implemented"); }
    function middleElide(path: string, maxChars: int): string { throw new Error("Format.middleElide: not implemented"); }
}
