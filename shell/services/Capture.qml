pragma Singleton
// Capture: freeze, crop, save, record, colour.
// Owner: S9. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // False until S9 fills this service; while false, Ipc answers "error: capture is not available yet"
    // instead of "ok" (aptus msg exits non-zero).
    readonly property bool available: false

    // what is being recorded: "region" | "screen" | ""
    property string recordingKind: ""
    // "Region 1280 × 720" or the monitor name
    property string recordingTarget: ""
    property bool recordingMic: false
    // the last capture: { path, kind: "image" | "video" | "colour", rect: {x,y,width,height}, monitor, at: Date } or null
    property var last: null

    property bool recording: false
    // Date
    property var recordingSince: null

    function region(): void { Log.info("service.capture", "region: not available yet"); }
    function screen(): void { Log.info("service.capture", "screen: not available yet"); }
    function window(): void { Log.info("service.capture", "window: not available yet"); }
    // Start a recording, or stop the running one.
    function record(): void { Log.info("service.capture", "record: not available yet"); }
    // Stop the running recording.
    function stop(): void { Log.info("service.capture", "stop: not available yet"); }
    function colour(): void { Log.info("service.capture", "colour: not available yet"); }
    // Record the whole active monitor.
    function recordScreen(): void { Log.info("service.capture", "recordScreen: not available yet"); }
    function setRecordingMic(on: bool): void { Log.info("service.capture", "setRecordingMic: not available yet"); }
}
