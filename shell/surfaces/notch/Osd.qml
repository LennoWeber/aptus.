// The OSD (surfaces/notch.md §8, M-07): glyph 20 · level 180 × 6 (spring.snappy, the part over
// 100 in warn) · value (tabular, ink.meta); the device name replaces the value for 1 s on a device
// change; the keyboard light shows three dots instead of a level.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The OSD payload (levels.js).
    property var payload: ({})

    // 300 × 44.
    readonly property real bulgeWidth: 0
    readonly property real bulgeHeight: 0

    // The device name shows instead of the value (osd.deviceNameMs after a device change).
    property bool _deviceShown: false
    property string _lastDevice: ""
}
