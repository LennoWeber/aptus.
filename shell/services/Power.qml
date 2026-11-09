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

    property bool hasBattery: false
    // 0..100
    property real percentage: 0
    property bool charging: false
    // s
    property int timeToEmpty: 0
    // s
    property int timeToFull: 0
    // "power-saver" | "balanced" | "performance"
    property string profile: ""
    // The service works (S3: battery).
    readonly property bool available: false
    // On AC (charging, or full on the charger).
    property bool pluggedIn: false

    // The battery toasts (05 §8): the warn toast was shown in this discharge; the crit toast's
    // passive entry (dismissed when plugged in).
    property bool _warned: false
    property int _critToast: 0
    function setProfile(name: string): void { Log.info("service.power", "setProfile: not available yet"); }

    // The battery toasts of 05 §8: warn once at ≤ 15 %, crit at ≤ 7 % until plugged in.
    function _checkBattery(): void { throw new Error("not implemented"); }
}
