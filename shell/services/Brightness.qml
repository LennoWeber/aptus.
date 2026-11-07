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

    // Backlight step for the hardware keys: direction ±1, fine = 1 % instead of brightness.step (OSD).
    function step(direction: int, fine: bool): void { throw new Error("Brightness.step: not implemented"); }
    // Keyboard light one level up or down (inert without an LED).
    function kbdStep(direction: int): void { throw new Error("Brightness.kbdStep: not implemented"); }
    function kbdToggle(): void { throw new Error("Brightness.kbdToggle: not implemented"); }
}
