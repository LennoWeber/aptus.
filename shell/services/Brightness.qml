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
    // The service works (S3).
    // TODO(phase): true once the root was scanned (also with no backlight: the keys stay inert).
    readonly property bool available: false

    // The sysfs root ($APTUS_SYSFS, else /sys; under APTUS_TEST without it: none).
    // TODO(phase): from Quickshell.env; a directory listing of class/backlight and class/leds
    //   (first backlight, first *::kbd_backlight) picks device/kbdDevice, then _read.
    readonly property string sysfs: ""
    // The backlight and keyboard-LED device names under class/backlight and class/leds.
    property string device: ""
    property string kbdDevice: ""
    // The backlight's max_brightness and raw value.
    property int max: 0
    property int raw: 0
    // The keyboard level before the last toggle (kbdToggle restores it).
    property int _kbdBefore: 0

    // Backlight step for the hardware keys: direction ±1, fine = 1 % instead of brightness.step (OSD).
    // TODO(phase): levels.js step on the percent scale, never below osd.brightnessMin (05 §6),
    //   set, _osd("brightness"); inert without a backlight.
    function step(direction: int, fine: bool): void { Log.info("service.brightness", "step: not available yet"); }
    // Keyboard light one level up or down (inert without an LED).
    // TODO(phase): clamp 0..kbdMax, _write(kbdDevice), _osd("kbd"); toggle: 0 ↔ the level before.
    function kbdStep(direction: int): void { Log.info("service.brightness", "kbdStep: not available yet"); }
    function kbdToggle(): void { Log.info("service.brightness", "kbdToggle: not available yet"); }
    // Backlight 0..1 (Spotlight "Brightness 40", Deck slider).
    // TODO(phase): raw = round(value × max), at least brightnessMin %, _write(device).
    function set(value: real): void { Log.info("service.brightness", "set: not available yet"); }

    // Read the backlight and LED files under `sysfs` (sysfs has no inotify: after every own write).
    function _read(): void { throw new Error("not implemented"); }
    // brightnessctl -d <device> set <value> (from PATH; the e2e tests put a fake first).
    function _write(device: string, value: int): void { throw new Error("not implemented"); }
    // Post the OSD ("brightness" on the monitor showing eDP-1, "kbd" on the active one), unless
    // the Deck is open there and has a slider for it (levels.js deckReplaces).
    function _osd(kind: string): void { throw new Error("not implemented"); }
}
