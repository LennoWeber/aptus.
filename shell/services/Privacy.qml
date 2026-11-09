pragma Singleton
// Privacy: mic, camera, screencast in use.
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // apps using the microphone
    property var mic: []
    // apps using a camera
    property var camera: []
    property bool screencast: false
    // The service works (S3); under APTUS_TEST only the screencast part (no PipeWire).
    readonly property bool available: false

    // Rebuild mic and camera from the PipeWire nodes (status.js privacy); never under Paths.test.
    function _rebuild(): void { throw new Error("not implemented"); }
}
