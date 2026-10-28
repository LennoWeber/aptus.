import QtQuick
import Quickshell
import Quickshell.Io

// Display state.
Scope {
    id: root

    property real brightness: 0.5  // 0..1
    property int widthPx
    property int heightPx
    property real scale
    property string output           // the built-in panel, e.g. eDP-1
    property int transform           // Hyprland transform 0..3
    property real refreshHz
    property var refreshChoices: []  // list of numbers, from the modes the panel reports
    readonly property string mode: ""   // the Hyprland mode string for the current size and rate, e.g. 1920x1080@60.00
    property bool restored            // the saved choice has been applied once
    readonly property var scaleChoices: [1, 1.25, 1.5]
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/aptus/display.json"

    // TODO(phase 7): call readMonitor() and restore() at start (Component.onCompleted), readMonitor again after every change
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
        throw new Error("not implemented")
    }

    function setScale(factor: real): void {
        if (!scaleChoices.includes(factor)) throw new Error("invariant: DisplayState.setScale: scale is not one of the offered choices")
        throw new Error("not implemented")
    }

    function setRefresh(hz: real): void {
        if (!refreshChoices.includes(hz)) throw new Error("invariant: DisplayState.setRefresh: rate is not one the panel offers")
        throw new Error("not implemented")
    }

    // Applies the saved choice once at start.
    function restore(): void {
        throw new Error("not implemented")
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
