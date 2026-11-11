pragma Singleton
// Power: battery and power profile.
// Owner: S3 (battery), S5 (profiles).
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.core
import "js/notifications.js" as N
import "js/status.js" as S

Singleton {
    id: root

    // profiles this machine offers ("power-saver", "balanced", "performance")
    property var profiles: []

    // UPower's display device (read only).
    readonly property var _dev: UPower.displayDevice
    readonly property bool hasBattery: !!_dev && _dev.isLaptopBattery && _dev.isPresent
    // 0..100 (UPower gives 0..1)
    readonly property real percentage: _dev ? _dev.percentage * 100 : 0
    readonly property bool charging: !!_dev && (_dev.state === UPowerDeviceState.Charging || _dev.state === UPowerDeviceState.PendingCharge)
    // s
    readonly property int timeToEmpty: _dev ? Math.round(_dev.timeToEmpty) : 0
    // s
    readonly property int timeToFull: _dev ? Math.round(_dev.timeToFull) : 0
    // "power-saver" | "balanced" | "performance" (the battery tooltip; setProfile is S5's)
    readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver"
        : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
    // The service works (S3: battery; also on a desktop without a battery).
    readonly property bool available: true
    // On AC (charging, or full on the charger).
    readonly property bool pluggedIn: !UPower.onBattery
    onPercentageChanged: _checkBattery()
    onPluggedInChanged: _pluggedChanged()

    // The battery toasts (05 §8): the warn toast was shown in this discharge; the crit toast's
    // passive entry (dismissed when plugged in).
    property bool _warned: false
    property int _critToast: 0
    function setProfile(name: string): void { Log.info("service.power", "setProfile: not available yet"); }

    // The battery toasts of 05 §8: warn once at ≤ 15 %, crit at ≤ 7 % until plugged in.
    function _checkBattery(): void {
        if (!hasBattery || pluggedIn) return;
        const b = Tokens.surfaces.bar, p = Math.round(percentage);
        // Found in review: own keys (one key let the warn toast replace the crit one in place) and
        // no warning after the crit toast (a start or resume at ≤ 7 %).
        if (p <= b.batteryCritPercent && _critToast === 0) {
            _warned = true;
            _critToast = SurfaceManager.post("toast", N.systemToast("Battery at " + p + " %", "Plug in now", "battery_alert", true, 0),
                                             N.CRITICAL_PRIORITY, "", "battery-crit");
        } else if (p <= b.batteryWarnPercent && !_warned) {
            _warned = true;
            SurfaceManager.post("toast", N.systemToast("Battery low · " + p + " %", "", "battery_alert", false,
                                                       Tokens.surfaces.toast.maxTimeoutMs), 0, "", "battery-low");
        }
    }
    // The charger was plugged in or out: plugged in → the event "Charging" (notch.md §7) and the
    // crit toast goes; a new discharge may warn again, at once when it starts low.
    function _pluggedChanged(): void {
        if (!hasBattery) return;
        if (!pluggedIn) { _checkBattery(); return; }
        if (_critToast) { SurfaceManager.dismiss(_critToast); _critToast = 0; }
        _warned = false;
        if (charging || percentage < 100) SurfaceManager.post("event", S.chargingEvent());
    }
}
