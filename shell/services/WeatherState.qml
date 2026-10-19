import QtQuick
import Quickshell

// Weather from Open-Meteo (CC BY 4.0, attribution is shown in the detail view). Refreshes every 30 minutes.
Scope {
    id: root

    property var appSettings
    property string locationName: appSettings ? appSettings.weatherLocationName : "Berlin"
    property real latitude: appSettings ? appSettings.weatherLatitude : 52.52
    property real longitude: appSettings ? appSettings.weatherLongitude : 13.405
    property string source: "open-meteo"
    property bool loaded
    property string error
    property real temperatureC
    property real feelsLikeC
    property string condition
    property string iconName: "cloud"
    property var hourly: []          // list of { time, temperatureC, iconName }
    property var daily: []           // list of { date, minC, maxC, iconName, condition }
    property var updatedAt           // Date

    // WMO weather codes -> text and symbol.
    function describe(code: int, isDay: bool): var {
        if (code === 0) return { text: "Clear", icon: "sun" }
        if (code === 1) return { text: "Mostly clear", icon: "sun" }
        if (code === 2) return { text: "Partly cloudy", icon: "partly" }
        if (code === 3) return { text: "Cloudy", icon: "cloud" }
        if (code === 45 || code === 48) return { text: "Fog", icon: "fog" }
        if (code >= 51 && code <= 57) return { text: "Drizzle", icon: "rain" }
        if (code >= 61 && code <= 67) return { text: "Rain", icon: "rain" }
        if (code >= 71 && code <= 77) return { text: "Snow", icon: "snow" }
        if (code >= 80 && code <= 82) return { text: "Showers", icon: "rain" }
        if (code === 85 || code === 86) return { text: "Snow showers", icon: "snow" }
        if (code >= 95) return { text: "Thunderstorm", icon: "storm" }
        return { text: "Unknown", icon: "cloud" }
    }

    function refresh(): void {
        if (!(latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180)) {
            error = "Invalid location"
            return
        }
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + latitude + "&longitude=" + longitude
            + "&current=temperature_2m,apparent_temperature,weather_code,is_day"
            + "&hourly=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&timezone=auto&forecast_days=6"
        const req = new XMLHttpRequest()
        req.onreadystatechange = () => {
            if (req.readyState !== XMLHttpRequest.DONE) return
            if (req.status !== 200) {
                root.error = "No connection"
                return
            }
            try {
                root.apply(JSON.parse(req.responseText))
                root.error = ""
            } catch (e) {
                root.error = "Unexpected answer"
            }
        }
        req.open("GET", url)
        req.send()
    }

    function apply(data: var): void {
        const cur = data.current
        const d = describe(cur.weather_code, cur.is_day === 1)
        temperatureC = cur.temperature_2m
        feelsLikeC = cur.apparent_temperature
        condition = d.text
        iconName = d.icon
        // Hours from now on.
        const now = new Date()
        const hours = []
        for (let i = 0; i < data.hourly.time.length && hours.length < 12; i++) {
            const t = new Date(data.hourly.time[i])
            if (t.getTime() < now.getTime() - 3600 * 1000) continue
            hours.push({ time: t, temperatureC: data.hourly.temperature_2m[i], iconName: describe(data.hourly.weather_code[i], true).icon })
        }
        hourly = hours
        const days = []
        for (let i = 0; i < data.daily.time.length; i++) {
            const dd = describe(data.daily.weather_code[i], true)
            days.push({ date: new Date(data.daily.time[i] + "T12:00:00"), minC: data.daily.temperature_2m_min[i], maxC: data.daily.temperature_2m_max[i], iconName: dd.icon, condition: dd.text })
        }
        daily = days
        updatedAt = new Date()
        loaded = true
    }

    // A changed location (settings load, user edit) refreshes once after the values settle.
    onLatitudeChanged: relocate.restart()
    onLongitudeChanged: relocate.restart()
    Timer {
        id: relocate
        interval: 300
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
}
