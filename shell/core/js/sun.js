.pragma library
// Sunrise and sunset (NOAA solar position algorithm, no network) for appearance.mode = auto and
// the night-light schedule (08-theming §2, 03 §2.6). Without a location: 07:00 and 19:00.

var FALLBACK_SUNRISE = [7, 0]
var FALLBACK_SUNSET = [19, 0]

var RAD = Math.PI / 180

// Private helpers.
// Minutes after local midnight of sunrise (rising) or sunset for the NOAA formulas, or
// null when the sun does not cross the horizon that day (polar day/night).
function eventMinutes(date, lat, lon, rising) {
    var start = new Date(date.getFullYear(), 0, 1)
    var dayOfYear = Math.floor((new Date(date.getFullYear(), date.getMonth(), date.getDate()) - start) / 86400000) + 1
    var noonOffset = 12
    var gamma = 2 * Math.PI / 365 * (dayOfYear - 1 + (noonOffset - 12) / 24)
    var eqtime = 229.18 * (0.000075 + 0.001868 * Math.cos(gamma) - 0.032077 * Math.sin(gamma)
                 - 0.014615 * Math.cos(2 * gamma) - 0.040849 * Math.sin(2 * gamma))
    var decl = 0.006918 - 0.399912 * Math.cos(gamma) + 0.070257 * Math.sin(gamma)
               - 0.006758 * Math.cos(2 * gamma) + 0.000907 * Math.sin(2 * gamma)
               - 0.002697 * Math.cos(3 * gamma) + 0.00148 * Math.sin(3 * gamma)
    var cosH = Math.cos(90.833 * RAD) / (Math.cos(lat * RAD) * Math.cos(decl)) - Math.tan(lat * RAD) * Math.tan(decl)
    if (cosH > 1 || cosH < -1) return { polar: cosH > 1 ? "night" : "day" }
    var ha = Math.acos(cosH) / RAD
    var utcMinutes = 720 - 4 * (lon + (rising ? ha : -ha)) - eqtime
    // local offset of that day (minutes east of UTC)
    var offset = -new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12).getTimezoneOffset()
    return { minutes: utcMinutes + offset }
}
function at(date, minutes) {
    var d = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0)
    return new Date(d.getTime() + Math.round(minutes * 60) * 1000)
}

// { sunrise: Date, sunset: Date } for the local calendar day of `date`; polar day/night clamp to
// the day's bounds. location: { lat, lon } or null.
function times(date, location) {
    if (!location || typeof location.lat !== "number" || typeof location.lon !== "number")
        return { sunrise: at(date, FALLBACK_SUNRISE[0] * 60 + FALLBACK_SUNRISE[1]),
                 sunset: at(date, FALLBACK_SUNSET[0] * 60 + FALLBACK_SUNSET[1]) }
    var r = eventMinutes(date, location.lat, location.lon, true)
    var s = eventMinutes(date, location.lat, location.lon, false)
    if (r.polar || s.polar) {
        var polar = r.polar || s.polar
        // polar day: light all day (sunrise at 00:00, sunset at 24:00); polar night: never light
        return polar === "day" ? { sunrise: at(date, 0), sunset: at(date, 24 * 60) }
                               : { sunrise: at(date, 12 * 60), sunset: at(date, 12 * 60) }
    }
    return { sunrise: at(date, r.minutes), sunset: at(date, s.minutes) }
}
// "light" between sunrise and sunset, else "dark".
function modeAt(date, location) {
    var t = times(date, location)
    return date >= t.sunrise && date < t.sunset ? "light" : "dark"
}
// The next Date after `date` at which modeAt changes.
function nextChange(date, location) {
    var t = times(date, location)
    if (date < t.sunrise && t.sunrise < t.sunset) return t.sunrise
    if (date < t.sunset && t.sunrise < t.sunset) return t.sunset
    for (var i = 1; i <= 366; i++) {
        var d = new Date(date.getFullYear(), date.getMonth(), date.getDate() + i, 12)
        var tt = times(d, location)
        if (tt.sunrise < tt.sunset) return tt.sunrise
    }
    return new Date(date.getTime() + 86400000)
}
