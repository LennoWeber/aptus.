.pragma library
// Formatting rules of 03-visual-language §4. English, 24 h, week starts Monday, decimal point.

var DAYS_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var DAYS_LONG = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
var MONTHS_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var MONTHS_LONG = ["January", "February", "March", "April", "May", "June", "July", "August",
                   "September", "October", "November", "December"]
var ELLIPSIS = "…"

function notImplemented(name) { throw new Error("format." + name + ": not implemented") }

function time(date) { notImplemented("time") }                  // "14:32"
function dateShort(date) { notImplemented("dateShort") }        // "Sat 7 Nov"
function dateLong(date) { notImplemented("dateLong") }          // "Saturday, 7 November"
function isoWeek(date) { notImplemented("isoWeek") }            // 45
function duration(seconds) { notImplemented("duration") }       // "3 h 10 min", "42 s", "5 min"
function clockDuration(seconds) { notImplemented("clockDuration") } // "24:10", "1:02:03"
function bytes(n) { notImplemented("bytes") }                   // "4.2 GB"
function percent(fraction) { notImplemented("percent") }        // "64 %"
function ago(ms, now) { notImplemented("ago") }                 // "now", "2 min ago", "3 h ago", "Mon"
function tildePath(path, home) { notImplemented("tildePath") }  // "/home/lenno/x" → "~/x"
// Middle truncation for paths ("~/Code/…/main.qml") to at most maxChars characters.
function middleElide(path, maxChars) { notImplemented("middleElide") }
