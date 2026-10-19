import QtQuick
import Quickshell
import Quickshell.Io

// Screenshot and screen recording with grim, slurp, wl-copy and wf-recorder. Missing tools are reported, not hidden.
Scope {
    id: root

    property bool recording
    property int recordingSec
    property string recordingTarget  // "screen" | "region"
    property bool recordAudio
    property string lastCapturePath
    property string saveDirectory: Quickshell.env("HOME") + "/Pictures/Screenshots"
    property string videoDirectory: Quickshell.env("HOME") + "/Videos/Recordings"
    property string lastError         // what the last capture said when it failed
    property string missingTools      // empty when everything needed is installed
    // The control center must be gone before the picture is taken.
    signal hideShellRequested()

    property string pendingKind
    property string pendingTarget

    function stamp(): string {
        const d = new Date()
        const p = n => (n < 10 ? "0" : "") + n
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + "_" + p(d.getHours()) + "-" + p(d.getMinutes()) + "-" + p(d.getSeconds())
    }

    // 'screen', 'region' or 'window'.
    function screenshot(target: string): void {
        if (["screen", "region", "window"].indexOf(target) < 0) throw new Error("invariant: CaptureState.screenshot: unknown target")
        pendingKind = "shot"
        pendingTarget = target
        hideShellRequested()
        delay.restart()
    }

    function startRecording(target: string): void {
        if (["screen", "region"].indexOf(target) < 0) throw new Error("invariant: CaptureState.startRecording: unknown target")
        if (recording) throw new Error("invariant: CaptureState.startRecording: already recording")
        pendingKind = "record"
        pendingTarget = target
        hideShellRequested()
        delay.restart()
    }

    function stopRecording(): void {
        if (!recording) throw new Error("invariant: CaptureState.stopRecording: not recording")
        // Ask politely (SIGINT finishes the file), and finish it off after a few seconds if it hangs.
        recordProc.signal(2)
        Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"])
        forceStop.restart()
    }

    function run(): void {
        console.log("aptus: capture " + pendingKind + " " + pendingTarget)
        if (pendingKind === "shot") {
            const path = saveDirectory + "/Screenshot_" + stamp() + ".png"
            shotProc.command = ["sh", "-c", shotScript, "sh", path, pendingTarget]
            shotProc.running = true
        } else {
            const path = videoDirectory + "/Recording_" + stamp() + ".mp4"
            recordProc.command = ["sh", "-c", recordScript, "sh", path, pendingTarget, recordAudio ? "audio" : "mute"]
            recordingTarget = pendingTarget
            lastCapturePath = path
            recordProc.running = true
        }
    }

    readonly property string shotScript: [
        "f=\"$1\"; mkdir -p \"$(dirname \"$f\")\"",
        "case \"$2\" in",
        "  region) g=$(slurp </dev/null) || exit 0; grim -g \"$g\" \"$f\" ;;",
        "  window) g=$(hyprctl -j activewindow | python3 -c 'import json,sys;w=json.load(sys.stdin);print(\"%d,%d %dx%d\"%(w[\"at\"][0],w[\"at\"][1],w[\"size\"][0],w[\"size\"][1]))') || exit 1; grim -g \"$g\" \"$f\" ;;",
        "  *) grim \"$f\" ;;",
        "esac || exit 1",
        "wl-copy < \"$f\"",
        "notify-send -a 'shell.' -i \"$f\" 'Screenshot saved' \"$f (copied to the clipboard)\"",
        "echo \"$f\""
    ].join("\n")

    readonly property string recordScript: [
        "f=\"$1\"; mkdir -p \"$(dirname \"$f\")\"",
        "a=\"\"; [ \"$3\" = audio ] && a=\"-a\"",
        "if [ \"$2\" = region ]; then g=$(slurp </dev/null) || exit 0; exec wf-recorder $a -g \"$g\" -f \"$f\"; fi",
        "o=$(hyprctl -j monitors | python3 -c 'import json,sys;m=json.load(sys.stdin);print((next((x for x in m if x.get(\"focused\")),m[0]))[\"name\"])')",
        "exec wf-recorder $a -o \"$o\" -f \"$f\""
    ].join("\n")

    Timer {
        id: forceStop
        interval: 4000
        onTriggered: if (root.recording) Quickshell.execDetached(["pkill", "-TERM", "-x", "wf-recorder"])
    }

    Timer {
        id: delay
        interval: 700   // the control center is unmapped at once; this gives the compositor time for a clean frame
        onTriggered: root.run()
    }

    function openFolder(): void {
        hideShellRequested()
        Quickshell.execDetached(["xdg-open", saveDirectory])
    }

    function openLast(): void {
        if (lastCapturePath !== "") Quickshell.execDetached(["xdg-open", lastCapturePath])
    }

    Process {
        id: shotProc
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "") { root.lastCapturePath = text.trim().split("\n").pop(); root.lastError = "" }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") { root.lastError = text.trim(); console.warn("aptus: capture: " + text.trim()) }
        }
        onExited: (code, status) => {
            if (code !== 0 && root.lastError === "") root.lastError = "The capture tool stopped with code " + code
            if (code !== 0) Quickshell.execDetached(["notify-send", "-a", "shell.", "Screenshot failed", root.lastError])
        }
    }

    Process {
        id: recordProc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") { root.lastError = text.trim().split("\n").slice(-3).join(" "); console.warn("aptus: recording: " + text.trim()) }
        }
        onRunningChanged: {
            root.recording = running
            if (running) root.recordingSec = 0
            else Quickshell.execDetached(["notify-send", "-a", "shell.", "Recording saved", root.lastCapturePath])
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.recordingSec += 1
    }

    // Which tools are missing, checked once.
    Process {
        running: true
        command: ["sh", "-c", "for t in grim slurp wl-copy wf-recorder; do command -v $t >/dev/null || printf '%s ' $t; done"]
        stdout: StdioCollector {
            onStreamFinished: root.missingTools = text.trim()
        }
    }
}
