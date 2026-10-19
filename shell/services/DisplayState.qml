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
        // TODO(phase 7, OSD section): show the on-screen indicator immediately on function-key presses.
        setBrightness(Math.max(0.01, Math.min(1, brightness + delta)))
    }
}
