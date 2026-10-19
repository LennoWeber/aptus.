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

    // The palette follows slowly: a change takes a few seconds, never a flash.
    Behavior on blend { NumberAnimation { duration: 4000; easing.type: Easing.InOutSine } }
    onBlendChanged: Tokens.applyPalette(Math.max(0, Math.min(1, blend)))

    // Scheduled mode checks once a minute.
    Timer {
        interval: 60000
        repeat: true
        running: root.scheduled
        triggeredOnStart: true
        onTriggered: {
            const hour = new Date().getHours()
            // TODO(phase 7, later): real sunrise and sunset from the weather location instead of fixed hours.
            const night = hour >= 20 || hour < 7
            if (night !== root.enabled) root.setEnabled(night)
        }
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
