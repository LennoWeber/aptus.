.pragma library
// Sunrise and sunset (NOAA solar position algorithm, no network) for appearance.mode = auto and
// the night-light schedule (08-theming §2, 03 §2.6). Without a location: 07:00 and 19:00.

var FALLBACK_SUNRISE = [7, 0]
var FALLBACK_SUNSET = [19, 0]

var RAD = Math.PI / 180

function notImplemented(name) { throw new Error("sun." + name + ": not implemented") }

// Private helpers.
// Minutes after local midnight of sunrise (rising) or sunset for the NOAA formulas, or
// null when the sun does not cross the horizon that day (polar day/night).
function eventMinutes(date, lat, lon, rising) { notImplemented("eventMinutes") }
function at(date, minutes) { notImplemented("at") }

// { sunrise: Date, sunset: Date } for the local calendar day of `date`; polar day/night clamp to
// the day's bounds. location: { lat, lon } or null.
function times(date, location) { notImplemented("times") }
// "light" between sunrise and sunset, else "dark".
function modeAt(date, location) { notImplemented("modeAt") }
// The next Date after `date` at which modeAt changes.
function nextChange(date, location) { notImplemented("nextChange") }
