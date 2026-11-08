.pragma library
// Formatting rules of 03-visual-language §4. English, 24 h, week starts Monday, decimal point.

var DAYS_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var DAYS_LONG = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
var MONTHS_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var MONTHS_LONG = ["January", "February", "March", "April", "May", "June", "July", "August",
                   "September", "October", "November", "December"]
var ELLIPSIS = "…"

// Private helpers.
function pad2(n) { return (n < 10 ? "0" : "") + n }

function time(date) { return pad2(date.getHours()) + ":" + pad2(date.getMinutes()) }              // "14:32"
function dateShort(date) {                                                                       // "Sat 7 Nov"
    return DAYS_SHORT[date.getDay()] + " " + date.getDate() + " " + MONTHS_SHORT[date.getMonth()]
}
function dateLong(date) {                                                                        // "Saturday, 7 November"
    return DAYS_LONG[date.getDay()] + ", " + date.getDate() + " " + MONTHS_LONG[date.getMonth()]
}
function isoWeek(date) {                                                                         // 45
    var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
    var day = d.getUTCDay() || 7
    d.setUTCDate(d.getUTCDate() + 4 - day)
    var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
    return Math.ceil(((d - yearStart) / 86400000 + 1) / 7)
}
function duration(seconds) {                                                                     // "3 h 10 min", "42 s", "5 min"
    var s = Math.max(0, Math.round(seconds))
    if (s < 60) return s + " s"
    var m = Math.round(s / 60)
    if (m < 60) return m + " min"
    var h = Math.floor(m / 60), rest = m % 60
    return rest ? h + " h " + rest + " min" : h + " h"
}
function clockDuration(seconds) {                                                                // "24:10", "1:02:03"
    var s = Math.max(0, Math.floor(seconds))
    var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60
    return h > 0 ? h + ":" + pad2(m) + ":" + pad2(sec) : m + ":" + pad2(sec)
}
function bytes(n) {                                                                              // "4.2 GB"
    var units = ["B", "kB", "MB", "GB", "TB"]
    var v = Math.max(0, n), i = 0
    while (v >= 1000 && i < units.length - 1) { v /= 1000; i++ }
    if (i === 0) return Math.round(v) + " B"
    return (v < 10 ? (Math.round(v * 10) / 10).toFixed(1) : String(Math.round(v))) + " " + units[i]
}
function percent(fraction) { return Math.round(fraction * 100) + " %" }                          // "64 %"
function ago(ms, now) {                                                                          // "now", "2 min ago", "3 h ago", "Mon"
    var d = Math.max(0, now - ms) / 1000
    if (d < 60) return "now"
    if (d < 3600) return Math.floor(d / 60) + " min ago"
    if (d < 86400) return Math.floor(d / 3600) + " h ago"
    var date = new Date(ms)
    if (d < 7 * 86400) return DAYS_SHORT[date.getDay()]
    return date.getDate() + " " + MONTHS_SHORT[date.getMonth()]
}
function tildePath(path, home) {                                                                 // "/home/lenno/x" → "~/x"
    if (!home) return path
    if (path === home) return "~"
    return path.indexOf(home + "/") === 0 ? "~" + path.substr(home.length) : path
}
// Middle truncation for paths ("~/Code/…/main.qml") to at most maxChars characters.
function middleElide(path, maxChars) {
    if (path.length <= maxChars) return path
    var parts = path.split("/")
    var last = parts[parts.length - 1]
    if (parts.length > 2) {
        // keep leading segments while they fit, then "…/", then the file name
        var head = parts[0]
        for (var i = 1; i < parts.length - 1; i++) {
            var next = head + "/" + parts[i]
            if ((next + "/" + ELLIPSIS + "/" + last).length > maxChars) break
            head = next
        }
        var out = head + "/" + ELLIPSIS + "/" + last
        if (out.length <= maxChars) return out
    }
    var keep = Math.max(1, maxChars - 1)
    var front = Math.ceil(keep / 2), back = Math.floor(keep / 2)
    return path.substr(0, front) + ELLIPSIS + path.substr(path.length - back)
}
