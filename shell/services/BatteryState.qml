import QtQuick
import Quickshell.Services.UPower
import qs.models

// Battery state (UPower).
QtObject {
    // The battery the laptop shows in its display device. UPower reports the charge as a fraction (0..1); this object
    // converts it to percent (0..100) once, here, so everything else works in percent.
    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device !== undefined && device.isPresent && device.isLaptopBattery
    property real percent: present && device.ready ? device.percentage * 100 : 0   // 0..100
    property bool charging: present && device.state === UPowerDeviceState.Charging
    property bool discharging: present && device.state === UPowerDeviceState.Discharging
    property bool fullyCharged: present && device.state === UPowerDeviceState.FullyCharged
    // Plugged in = the battery is not being drained. UPower.onBattery alone is wrong when the laptop charges a phone.
    property bool pluggedIn: present ? !discharging : !UPower.onBattery
    property int timeRemainingMin: {                                                // -1 if unknown
        if (!present) return -1
        let seconds = charging ? device.timeToFull : (discharging ? device.timeToEmpty : 0)
        // UPower often reports 0 for a while after the cable changes; then estimate from the current power draw.
        const watts = Math.abs(device.changeRate)
        if (!(seconds > 0) && watts > 0.5 && (charging || discharging)) {
            const wattHours = charging ? device.energyCapacity - device.energy : device.energy
            seconds = wattHours / watts * 3600
        }
        return seconds > 0 ? Math.round(seconds / 60) : -1
    }
    property int severity: severityFor(percent, charging)   // Enums.Severity, from the thresholds below
    property int warnBelowPercent: 20
    property int criticalBelowPercent: 10

    // One line for the dropdown and the detail view: "1 h 20 min left", "Charging", "Fully charged" ...
    function statusText(): string {
        if (!present) return ""
        if (fullyCharged) return "Fully charged"
        if (timeRemainingMin < 0) return charging ? "Charging" : (discharging ? "On battery" : "Plugged in")
        const h = Math.floor(timeRemainingMin / 60)
        const m = timeRemainingMin % 60
        const t = (h > 0 ? h + " h " : "") + m + " min"
        return charging ? t + " until full" : t + " left"
    }

    // Enums.Severity for a charge level.
    function severityFor(level: real, isCharging: bool): int {
        if (isCharging) return Enums.Severity.Neutral
        if (level <= criticalBelowPercent) return Enums.Severity.Critical
        if (level <= warnBelowPercent) return Enums.Severity.Warn
        return Enums.Severity.Neutral
    }
}
