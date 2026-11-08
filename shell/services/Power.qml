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
    function setProfile(name: string): void { Log.info("service.power", "setProfile: not available yet"); }
}
