pragma Singleton
pragma ComponentBehavior: Bound
// Brightness: eDP-1 backlight, keyboard LED.
// Owner: S3.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import "js/levels.js" as L
import "js/hypr.js" as H

Singleton {
    id: root

    // 0..1
    readonly property real brightness: max > 0 ? raw / max : 0
    readonly property bool hasBacklight: device !== "" && max > 0
    property int kbdLevel: 0
    // 0 = no keyboard light
    property int kbdMax: 0
    // The service works (S3): true once the root was scanned (also with no backlight: the keys
    // stay inert).
    readonly property bool available: _scanned

    // The sysfs root ($APTUS_SYSFS, else /sys; under APTUS_TEST only $APTUS_SYSFS inside HOME,
    // else none).
    readonly property string sysfs: Paths.sysfsOverride !== "" ? Paths.sysfsOverride : Paths.test ? "" : "/sys"
    // The backlight and keyboard-LED device names under class/backlight and class/leds.
    property string device: ""
    property string kbdDevice: ""
    // The backlight's max_brightness and raw value.
    property int max: 0
    property int raw: 0
    // The keyboard level before the last toggle (kbdToggle restores it).
    property int _kbdBefore: 0
    // Found by the probe (phase 5):
    // The first scan of `sysfs` has run (available follows it, also without a backlight).
    property bool _scanned: false
    // The write waiting for the running brightnessctl: [device, value] per device.
    property var _queue: ({})

    // Backlight step for the hardware keys: direction ±1, fine = 1 % instead of brightness.step (OSD).
    function step(direction: int, fine: bool): void {
        if (!hasBacklight) return;
        const stepPct = fine ? 1 : (Config.get("brightness.step") || 5);
        const next = L.step(brightness * 100, direction, stepPct, Tokens.surfaces.osd.brightnessMin, 100);
        set(next / 100);
        _osd("brightness");
    }
    // Keyboard light one level up or down (inert without an LED).
    function kbdStep(direction: int): void {
        if (kbdDevice === "" || kbdMax <= 0) return;
        kbdLevel = Math.max(0, Math.min(kbdMax, kbdLevel + (direction > 0 ? 1 : -1)));
        _write(kbdDevice, kbdLevel);
        _osd("kbd");
    }
    function kbdToggle(): void {
        if (kbdDevice === "" || kbdMax <= 0) return;
        if (kbdLevel > 0) { _kbdBefore = kbdLevel; kbdLevel = 0; }
        else kbdLevel = _kbdBefore > 0 ? _kbdBefore : kbdMax;
        _write(kbdDevice, kbdLevel);
        _osd("kbd");
    }
    // Backlight 0..1 (Spotlight "Brightness 40", Deck slider).
    function set(value: real): void {
        if (!hasBacklight) return;
        const minRaw = Math.ceil(max * Tokens.surfaces.osd.brightnessMin / 100);
        raw = Math.max(minRaw, Math.min(max, Math.round(value * max)));
        _write(device, raw);
    }

    // Read the backlight and LED levels under `sysfs` (sysfs has no inotify: after every own
    // write). E14: the maxima are constant; their views load once, when the scan names the device.
    function _read(): void {
        if (device !== "") backlightNow.reload();
        if (kbdDevice !== "") kbdNow.reload();
    }
    // brightnessctl -d <device> set <value> (from PATH; the e2e tests put a fake first). One run
    // at a time; a newer value for the same device replaces the queued one.
    function _write(dev: string, value: int): void {
        if (_refused(dev)) return;
        const q = Object.assign({}, _queue);
        q[dev] = value;
        _queue = q;
        if (!writer.running) _next();
    }
    // Start the next queued write when brightnessctl has finished (then _read).
    // Invariant (phase 6): only _write fills the queue (after _refused), one value per device,
    // a whole number in 0..max; a queued write passes _refused again before its process starts.
    function _next(): void {
        const devs = Object.keys(_queue);
        if (devs.length === 0) { _read(); return; }
        const q = Object.assign({}, _queue);
        const v = q[devs[0]];
        delete q[devs[0]];
        _queue = q;
        if (_refused(devs[0])) { _next(); return; }
        writer.command = ["brightnessctl", "-q", "-d", devs[0], "set", String(v)];
        writer.running = true;
    }
    // Invariant (phase 6): a test shell never writes the real backlight or keyboard light. Under
    // APTUS_TEST only a tree from APTUS_SYSFS inside the test HOME is written (the rule Paths
    // applies to the XDG directories), and only its test devices (fakehw.py names them
    // aptus_test…: a real brightnessctl that slipped onto PATH finds no such device).
    function _refused(dev: string): bool {
        if (!Paths.test || (sysfs !== "" && dev.indexOf("aptus_test") === 0)) return false;
        Log.error("service.brightness", "write to " + dev + " under " + (sysfs || "no sysfs") + " refused in a test");
        return true;
    }
    // Post the OSD ("brightness" on the internal monitor eDP-1, "kbd" on the active one), unless
    // the Deck is open there and has a slider for it (levels.js deckReplaces).
    function _osd(kind: string): void {
        const mon = kind === "brightness" && SurfaceManager.monitorState(H.INTERNAL) ? H.INTERNAL : SurfaceManager.activeMonitor;
        const m = SurfaceManager.monitorState(mon);
        if (m && m.deck && L.deckReplaces(kind)) return;
        SurfaceManager.post("osd", kind === "kbd" ? L.kbdOsd(kbdLevel, kbdMax) : L.brightnessOsd(brightness), 0, mon, kind);
    }

    Process {
        id: writer
        onRunningChanged: if (!running) root._next()
    }
    // The device scan: the first backlight, the first *::kbd_backlight.
    Process {
        id: scan
        command: ["sh", "-c", 'ls -1 "$1/class/backlight" 2>/dev/null | head -n1; echo "--"; ls -1 "$1/class/leds" 2>/dev/null | grep "::kbd_backlight$" | head -n1', "sh", root.sysfs]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("--");
                root.device = (parts[0] || "").trim();
                root.kbdDevice = (parts[1] || "").trim();
                root._scanned = true;
                root._read();
            }
        }
    }
    Component.onCompleted: {
        if (sysfs === "") _scanned = true;
        else scan.running = true;
    }
    FileView {
        id: backlightNow
        path: root.device !== "" ? root.sysfs + "/class/backlight/" + root.device + "/brightness" : ""
        printErrors: false
        onLoaded: root.raw = parseInt(text()) || 0
    }
    FileView {
        id: backlightMax
        path: root.device !== "" ? root.sysfs + "/class/backlight/" + root.device + "/max_brightness" : ""
        printErrors: false
        onLoaded: root.max = parseInt(text()) || 0
    }
    FileView {
        id: kbdNow
        path: root.kbdDevice !== "" ? root.sysfs + "/class/leds/" + root.kbdDevice + "/brightness" : ""
        printErrors: false
        onLoaded: root.kbdLevel = parseInt(text()) || 0
    }
    FileView {
        id: kbdMaxView
        path: root.kbdDevice !== "" ? root.sysfs + "/class/leds/" + root.kbdDevice + "/max_brightness" : ""
        printErrors: false
        onLoaded: root.kbdMax = parseInt(text()) || 0
    }
}
