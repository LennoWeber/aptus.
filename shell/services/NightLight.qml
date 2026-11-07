pragma Singleton
// NightLight: temperature, schedule, sun times (hyprsunset).
// Owner: S5. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool active: false
    // K, 0 = identity
    property int temperature: 0
    // Date of today's sunrise (NOAA, from weather.location)
    property var sunrise: null
    // Date of today's sunset
    property var sunset: null
    function setActive(on: bool): void { throw new Error("NightLight.setActive: not implemented"); }
    function setTemperature(kelvin: int): void { throw new Error("NightLight.setTemperature: not implemented"); }
}
