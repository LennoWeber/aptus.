pragma Singleton
// Brightness: eDP-1 backlight, keyboard LED.
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // 0..1
    property real brightness: 0
    property bool hasBacklight: false
    property int kbdLevel: 0
    // 0 = no keyboard light
    property int kbdMax: 0

    // Backlight step for the hardware keys: direction ±1, fine = 1 % instead of brightness.step (OSD).
    function step(direction: int, fine: bool): void { Log.info("service.brightness", "step: not available yet"); }
    // Keyboard light one level up or down (inert without an LED).
    function kbdStep(direction: int): void { Log.info("service.brightness", "kbdStep: not available yet"); }
    function kbdToggle(): void { Log.info("service.brightness", "kbdToggle: not available yet"); }
    // Backlight 0..1 (Spotlight "Brightness 40", Deck slider).
    function set(value: real): void { Log.info("service.brightness", "set: not available yet"); }
}
