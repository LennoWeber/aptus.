import QtQuick
import Quickshell
import Quickshell.Io

// Display state.
Scope {
    id: root

    property real brightness: 0.5  // 0..1
    property int widthPx
    property int heightPx
    property real scale: 1
    property string output           // the built-in panel, e.g. eDP-1
    property int transform           // Hyprland transform 0..3
    property real refreshHz
    property var refreshChoices: []  // list of numbers, from the modes the panel reports
    readonly property var scaleChoices: [1, 1.25, 1.5]
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/aptus/display.json"

    // The Hyprland mode string for the current size and rate, e.g. 1920x1080@60.00.
    readonly property string mode: output ? widthPx + "x" + heightPx + "@" + refreshHz.toFixed(2) : "1920x1080@60"

    Component.onCompleted: readMonitor()

    Timer {
        id: recheck
        interval: 700
        onTriggered: root.readMonitor()
    }

    FileView {
        id: savedView
        path: root.stateFile
        blockLoading: true
        printErrors: false
    }

    // The built-in panel (eDP-*) from hyprctl; the first start also applies the saved choice.
    property bool restored            // the saved choice has been applied once
    Process {
        id: monitorReader
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = JSON.parse(text)
                const m = list.find(x => x.name.startsWith("eDP")) || list[0]
                if (!m) return
                root.output = m.name
                root.widthPx = m.width
                root.heightPx = m.height
                root.transform = m.transform
                root.scale = m.scale
                const hzs = (m.availableModes || []).filter(x => x.startsWith(m.width + "x" + m.height + "@")).map(x => Number(x.split("@")[1].replace("Hz", "")))
                root.refreshChoices = Array.from(new Set(hzs)).sort((a, b) => b - a)
                const near = root.refreshChoices.find(h => Math.abs(h - m.refreshRate) < 0.5)
                root.refreshHz = near !== undefined ? near : m.refreshRate
                if (!root.restored) {
                    root.restored = true
                    root.restore()
                }
            }
        }
    }

    // brightnessctl prints "current,max" in machine mode; read once at start and after every change.
    Process {
        id: reader
        command: ["brightnessctl", "-m", "-c", "backlight"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",")
                // name,class,current,percent,max
                if (parts.length >= 5 && Number(parts[4]) > 0) root.brightness = Number(parts[2]) / Number(parts[4])
            }
        }
    }

    // Reads panel name, transform, scale and the refresh rates it offers.
    function readMonitor(): void {
        if (!monitorReader.running) monitorReader.running = true
    }

    function setScale(factor: real): void {
        if (!scaleChoices.includes(factor)) throw new Error("invariant: DisplayState.setScale: scale is not one of the offered choices")
        apply(factor, refreshHz)
    }

    function setRefresh(hz: real): void {
        if (!refreshChoices.includes(hz)) throw new Error("invariant: DisplayState.setRefresh: rate is not one the panel offers")
        apply(scale, hz)
    }

    // One call for both: Hyprland takes the whole monitor line. The choice is kept in a small file and applied again at start.
    function apply(factor: real, hz: real): void {
        if (!output) return
        scale = factor
        refreshHz = hz
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.monitor({ output = '" + output + "', mode = '" + mode + "', position = '0x0', scale = '" + factor + "', transform = " + transform + " })"])
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"", "sh", stateFile, JSON.stringify({ scale: factor, refresh: hz })])
        recheck.restart()
    }

    // Applies the saved choice once at start.
    function restore(): void {
        try {
            const saved = JSON.parse(savedView.text())
            if (scaleChoices.includes(saved.scale) && output) apply(saved.scale, refreshChoices.includes(saved.refresh) ? saved.refresh : refreshHz)
        } catch (e) {
            // nothing saved yet
        }
    }

    function setBrightness(level: real): void {
        if (!(level >= 0 && level <= 1)) throw new Error("invariant: DisplayState.setBrightness: brightness outside 0..1")
        // Never fully dark: 1 % is the floor so the screen cannot be lost.
        const percent = Math.max(1, Math.round(level * 100))
        brightness = percent / 100
        Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", percent + "%"])
    }

    // Function keys.
    function changeBrightness(delta: real): void {
        if (!Number.isFinite(delta)) throw new Error("invariant: DisplayState.changeBrightness: delta must be a number")
        setBrightness(Math.max(0.01, Math.min(1, brightness + delta)))
    }
}
