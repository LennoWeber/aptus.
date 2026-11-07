pragma Singleton
// Brightness: eDP-1 backlight, keyboard LED.
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // 0..1
    property real brightness: 0
    property bool hasBacklight: false
    property int kbdLevel: 0
    // 0 = no keyboard light
    property int kbdMax: 0
}
