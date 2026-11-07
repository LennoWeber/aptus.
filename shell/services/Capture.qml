pragma Singleton
// Capture: freeze, crop, save, record, colour.
// Owner: S9. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

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

    function region(): void { throw new Error("Capture.region: not implemented"); }
    function screen(): void { throw new Error("Capture.screen: not implemented"); }
    function window(): void { throw new Error("Capture.window: not implemented"); }
    // Start a recording, or stop the running one.
    function record(): void { throw new Error("Capture.record: not implemented"); }
    // Stop the running recording.
    function stop(): void { throw new Error("Capture.stop: not implemented"); }
    function colour(): void { throw new Error("Capture.colour: not implemented"); }
    // Record the whole active monitor.
    function recordScreen(): void { throw new Error("Capture.recordScreen: not implemented"); }
    function setRecordingMic(on: bool): void { throw new Error("Capture.setRecordingMic: not implemented"); }
}
