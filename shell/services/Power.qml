pragma Singleton
// Power: battery and power profile.
// Owner: S3 (battery), S5 (profiles). Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // profiles this machine offers ("power-saver", "balanced", "performance")
    property var profiles: []

    // TODO(phase): hasBattery … timeToFull from UPower.displayDevice (isLaptopBattery, isPresent;
    //   percentage 0..1 × 100; read only); percentage changes → _checkBattery.
    property bool hasBattery: false
    // 0..100
    property real percentage: 0
    property bool charging: false
    // s
    property int timeToEmpty: 0
    // s
    property int timeToFull: 0
    // "power-saver" | "balanced" | "performance"
    // TODO(phase): read from PowerProfiles.profile for the battery tooltip (setProfile is S5's).
    property string profile: ""
    // The service works (S3: battery).
    // TODO(phase): true once UPower answered (also on a desktop without a battery).
    readonly property bool available: false
    // On AC (charging, or full on the charger).
    // TODO(phase): !UPower.onBattery; changes → _pluggedChanged.
    property bool pluggedIn: false

    // The battery toasts (05 §8): the warn toast was shown in this discharge; the crit toast's
    // passive entry (dismissed when plugged in).
    property bool _warned: false
    property int _critToast: 0
    function setProfile(name: string): void { Log.info("service.power", "setProfile: not available yet"); }

    // The battery toasts of 05 §8: warn once at ≤ 15 %, crit at ≤ 7 % until plugged in.
    function _checkBattery(): void { throw new Error("not implemented"); }
    // The charger was plugged in or out: plugged in → the event "Charging" (notch.md §7) and the
    // crit toast goes; a new discharge may warn again.
    function _pluggedChanged(): void { throw new Error("not implemented"); }

    // Found by the probe (phase 5):
    // UPower's display device (read only; null before UPower answers).
    // TODO(phase): UPower.displayDevice.
    readonly property var _dev: null
}
