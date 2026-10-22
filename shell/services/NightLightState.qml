import QtQuick
import Quickshell
import qs.theme

// Night light (hyprsunset) state. The palette blends day -> night with `blend`.
Scope {
    id: root

    property bool enabled
    property bool scheduled      // follows the evening and morning hours
    property int temperatureK: 4200   // current colour temperature
    property int minTemperatureK: 3000
    property int maxTemperatureK: 6500
    property real blend          // 0 = day palette, 1 = night palette
    property real latitude: 52.52     // from the weather location
    property real longitude: 13.405
    property var now: new Date()
    readonly property var sun: sunTimes(now, latitude, longitude)   // { sunrise, sunset } or null (polar)
    readonly property string scheduleText: sun ? "Sunset to sunrise (" + Qt.formatTime(sun.sunset, "HH:mm") + " to " + Qt.formatTime(sun.sunrise, "HH:mm") + ")" : "Evening to morning (20:00 to 07:00)"

    // The palette follows slowly: a change takes a few seconds, never a flash.
    Behavior on blend { NumberAnimation { duration: 4000; easing.type: Easing.InOutSine } }
    // TODO(phase 7, Bild-Theming): with a style as source the shell root calls Tokens.refreshTheme(entries) so nightShift applies; the Standard source keeps applyPalette.
    onBlendChanged: Tokens.applyPalette(Math.max(0, Math.min(1, blend)))

    // Scheduled mode checks once a minute.
    Timer {
        interval: 60000
        repeat: true
        running: root.scheduled
        triggeredOnStart: true
        onTriggered: {
            root.now = new Date()
            const night = root.isNight(root.now)
            if (night !== root.enabled) root.setEnabled(night)
        }
    }

    // Sunrise equation (Julian days), local sunrise and sunset of the day of `date`; null in polar day or night.
    function sunTimes(date: var, lat: real, lon: real): var {
        const rad = Math.PI / 180
        const jd = date.getTime() / 86400000 + 2440587.5
        const n = Math.ceil(jd - 2451545.0 + 0.0008)
        const js = n - lon / 360
        const m = (357.5291 + 0.98560028 * js) % 360
        const c = 1.9148 * Math.sin(m * rad) + 0.02 * Math.sin(2 * m * rad) + 0.0003 * Math.sin(3 * m * rad)
        const lambda = (m + c + 180 + 102.9372) % 360
        const jt = 2451545.0 + js + 0.0053 * Math.sin(m * rad) - 0.0069 * Math.sin(2 * lambda * rad)
        const decl = Math.asin(Math.sin(lambda * rad) * Math.sin(23.4397 * rad))
        const cosOmega = (Math.sin(-0.833 * rad) - Math.sin(lat * rad) * Math.sin(decl)) / (Math.cos(lat * rad) * Math.cos(decl))
        if (!(cosOmega >= -1 && cosOmega <= 1)) return null
        const omega = Math.acos(cosOmega) / rad
        const toDate = j => new Date((j - 2440587.5) * 86400000)
        return { sunrise: toDate(jt - omega / 360), sunset: toDate(jt + omega / 360) }
    }

    // After sunset or before sunrise (fixed 20:00 to 07:00 where the sun gives no answer).
    function isNight(date: var): bool {
        const s = sunTimes(date, latitude, longitude)
        if (!s) {
            const h = date.getHours()
            return h >= 20 || h < 7
        }
        // sunTimes works on the calendar day of `date`; compare by time of day.
        const t = date.getHours() * 60 + date.getMinutes()
        const rise = s.sunrise.getHours() * 60 + s.sunrise.getMinutes()
        const set = s.sunset.getHours() * 60 + s.sunset.getMinutes()
        return t < rise || t >= set
    }

    function setEnabled(on: bool): void {
        enabled = on
        if (on) {
            // hyprsunset is started when it is not running yet, then told the temperature.
            Quickshell.execDetached(["sh", "-c", "pgrep -x hyprsunset >/dev/null || (setsid hyprsunset >/dev/null 2>&1 &); sleep 0.4; hyprctl hyprsunset temperature " + temperatureK])
        } else {
            Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"])
        }
        updateBlend()
    }

    function setTemperature(kelvin: int): void {
        if (kelvin < minTemperatureK || kelvin > maxTemperatureK) throw new Error("invariant: NightLightState.setTemperature: temperature outside the allowed range")
        temperatureK = kelvin
        if (enabled) Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(kelvin)])
        updateBlend()
    }

    function setScheduled(on: bool): void {
        scheduled = on
    }

    // Move the palette blend slowly, never in jumps.
    function updateBlend(): void {
        if (minTemperatureK >= maxTemperatureK) throw new Error("invariant: NightLightState.updateBlend: min temperature must be below max")
        // Warmer than 6500 K means more night: 6500 K -> 0, minTemperatureK -> 1.
        blend = enabled ? Math.max(0, Math.min(1, (maxTemperatureK - temperatureK) / (maxTemperatureK - minTemperatureK))) : 0
    }
}
