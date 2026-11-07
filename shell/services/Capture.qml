pragma Singleton
// Capture: freeze, crop, save, record, colour.
// Owner: S9. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

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
}
